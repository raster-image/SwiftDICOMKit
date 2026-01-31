// PatientSearchView.swift
// DICOMViewer
//
// View for searching patients on a PACS server
//

import SwiftUI

/// View for searching patients on a PACS server.
///
/// Provides a search form with patient name, ID, birth date, and sex filters,
/// along with quick filter options for common date ranges.
struct PatientSearchView: View {
    @Environment(AppState.self) private var appState
    let server: PACSServer
    
    @State private var patientName = ""
    @State private var patientID = ""
    @State private var birthDateFrom: Date?
    @State private var birthDateTo: Date?
    @State private var selectedSex: PatientSex?
    @State private var showBirthDateFrom = false
    @State private var showBirthDateTo = false
    
    var body: some View {
        List {
            // Search Form
            Section("Search Criteria") {
                TextField("Patient Name (e.g., SMITH* or *JOHN*)", text: $patientName)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                
                TextField("Patient ID", text: $patientID)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            
            Section("Filters") {
                // Sex picker
                Picker("Sex", selection: $selectedSex) {
                    Text("Any").tag(PatientSex?.none)
                    ForEach(PatientSex.allCases, id: \.self) { sex in
                        Text(sex.displayName).tag(Optional(sex))
                    }
                }
                
                // Birth date range
                Toggle("Filter by Birth Date", isOn: $showBirthDateFrom)
                
                if showBirthDateFrom {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { birthDateFrom ?? Date() },
                            set: { birthDateFrom = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { birthDateTo ?? Date() },
                            set: { birthDateTo = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }
            
            Section {
                HStack {
                    Button {
                        clearSearch()
                    } label: {
                        Text("Clear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        performSearch()
                    } label: {
                        HStack {
                            if appState.isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Search")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.isSearching)
                }
            }
            
            // Quick Filters
            Section("Quick Filters") {
                HStack {
                    QuickFilterButton(title: "Today") {
                        applyQuickFilter(.today)
                    }
                    QuickFilterButton(title: "This Week") {
                        applyQuickFilter(.thisWeek)
                    }
                    QuickFilterButton(title: "This Month") {
                        applyQuickFilter(.thisMonth)
                    }
                }
            }
            
            // Results
            if !appState.patientResults.isEmpty {
                Section("Results (\(appState.patientResults.count))") {
                    ForEach(appState.patientResults) { patient in
                        PatientRowView(patient: patient) {
                            appState.navigateToStudyList(patient: patient)
                        }
                    }
                }
            } else if !appState.isSearching && hasSearched {
                Section {
                    ContentUnavailableView(
                        "No Patients Found",
                        systemImage: "person.slash",
                        description: Text("Try adjusting your search criteria.")
                    )
                }
            }
        }
        .navigationTitle("Patient Search")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Patient Search")
                        .font(.headline)
                    Text(server.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable {
            performSearch()
        }
    }
    
    @State private var hasSearched = false
    
    private func performSearch() {
        hasSearched = true
        
        appState.searchCriteria = PatientSearchCriteria(
            patientName: patientName,
            patientID: patientID,
            birthDateFrom: showBirthDateFrom ? birthDateFrom : nil,
            birthDateTo: showBirthDateFrom ? birthDateTo : nil,
            sex: selectedSex
        )
        
        Task {
            await appState.searchPatients()
        }
    }
    
    private func clearSearch() {
        patientName = ""
        patientID = ""
        birthDateFrom = nil
        birthDateTo = nil
        selectedSex = nil
        showBirthDateFrom = false
        hasSearched = false
        appState.patientResults = []
    }
    
    private func applyQuickFilter(_ criteria: PatientSearchCriteria) {
        appState.searchCriteria = criteria
        Task {
            await appState.searchPatients()
        }
    }
}

/// A button for quick filter options.
struct QuickFilterButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }
}

/// A row displaying a single patient.
struct PatientRowView: View {
    let patient: PatientDisplayModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.formattedName)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Label(patient.patientID, systemImage: "number")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let sex = patient.sex {
                            Text(sex.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(sexColor(sex).opacity(0.2))
                                .foregroundStyle(sexColor(sex))
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let birthDate = patient.formattedBirthDate {
                            Label(birthDate, systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let age = patient.ageString {
                            Text("(\(age))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if let studyCount = patient.numberOfStudies {
                    VStack {
                        Text("\(studyCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(studyCount == 1 ? "study" : "studies")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func sexColor(_ sex: PatientSex) -> Color {
        switch sex {
        case .male: return .blue
        case .female: return .pink
        case .other: return .purple
        }
    }
}

#Preview {
    NavigationStack {
        PatientSearchView(server: .sample)
    }
    .environment(AppState())
}

#Preview("With Results") {
    let appState = AppState()
    appState.patientResults = PatientDisplayModel.sampleList
    
    return NavigationStack {
        PatientSearchView(server: .sample)
    }
    .environment(appState)
}
