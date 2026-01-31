// StudyListView.swift
// DICOMViewer
//
// View for displaying studies for a selected patient
//

import SwiftUI

/// Displays a list of studies for a selected patient.
///
/// Shows study details including date, description, modalities, and
/// series/image counts. Allows drill-down to series list.
struct StudyListView: View {
    @Environment(AppState.self) private var appState
    let server: PACSServer
    let patient: PatientDisplayModel
    
    @State private var sortOrder: StudySortOrder = .dateDescending
    @State private var modalityFilter: String?
    
    var body: some View {
        List {
            // Patient header
            Section {
                PatientHeaderView(patient: patient)
            }
            
            // Filter and sort options
            Section {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(StudySortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                
                if !availableModalities.isEmpty {
                    Picker("Modality", selection: $modalityFilter) {
                        Text("All").tag(String?.none)
                        ForEach(availableModalities, id: \.self) { modality in
                            Text(modality).tag(Optional(modality))
                        }
                    }
                }
            }
            
            // Studies list
            if appState.isLoadingStudies {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading studies...")
                        Spacer()
                    }
                    .padding()
                }
            } else if filteredStudies.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Studies",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("No studies found for this patient.")
                    )
                }
            } else {
                Section("Studies (\(filteredStudies.count))") {
                    ForEach(sortedStudies) { study in
                        StudyRowView(study: study) {
                            appState.navigateToSeriesList(study: study)
                        }
                    }
                }
            }
        }
        .navigationTitle("Studies")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStudies()
        }
        .refreshable {
            await loadStudies()
        }
    }
    
    private var filteredStudies: [StudyDisplayModel] {
        guard let filter = modalityFilter else {
            return appState.studyResults
        }
        return appState.studyResults.filter { study in
            study.modalitiesInStudy.contains(filter)
        }
    }
    
    private var sortedStudies: [StudyDisplayModel] {
        switch sortOrder {
        case .dateDescending:
            return filteredStudies.sorted { ($0.studyDate ?? .distantPast) > ($1.studyDate ?? .distantPast) }
        case .dateAscending:
            return filteredStudies.sorted { ($0.studyDate ?? .distantPast) < ($1.studyDate ?? .distantPast) }
        case .modality:
            return filteredStudies.sorted { $0.modalitiesString < $1.modalitiesString }
        case .description:
            return filteredStudies.sorted { $0.studyDescription < $1.studyDescription }
        }
    }
    
    private var availableModalities: [String] {
        let allModalities = appState.studyResults.flatMap { $0.modalitiesInStudy }
        return Array(Set(allModalities)).sorted()
    }
    
    private func loadStudies() async {
        appState.selectedPatient = patient
        await appState.loadStudies()
    }
}

/// Sort order options for studies.
enum StudySortOrder: CaseIterable {
    case dateDescending
    case dateAscending
    case modality
    case description
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Date (Newest)"
        case .dateAscending: return "Date (Oldest)"
        case .modality: return "Modality"
        case .description: return "Description"
        }
    }
}

/// Header view showing patient information.
struct PatientHeaderView: View {
    let patient: PatientDisplayModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundStyle(.accent)
                
                VStack(alignment: .leading) {
                    Text(patient.formattedName)
                        .font(.headline)
                    Text("ID: \(patient.patientID)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                if let birthDate = patient.formattedBirthDate {
                    Label(birthDate, systemImage: "calendar")
                        .font(.caption)
                }
                
                if let age = patient.ageString {
                    Label(age, systemImage: "person.badge.clock")
                        .font(.caption)
                }
                
                if let sex = patient.sex {
                    Label(sex.displayName, systemImage: sex == .male ? "figure.stand" : "figure.stand.dress")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// A row displaying a single study.
struct StudyRowView: View {
    let study: StudyDisplayModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Modality badge
                if let modality = study.modalitiesInStudy.first {
                    ModalityBadge(modality: modality)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Study description
                    Text(study.studyDescription.isEmpty ? "Untitled Study" : study.studyDescription)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Date and accession number
                    HStack(spacing: 8) {
                        if let date = study.formattedStudyDate {
                            Label(date, systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !study.accessionNumber.isEmpty {
                            Label(study.accessionNumber, systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Modalities and counts
                    HStack(spacing: 12) {
                        if study.modalitiesInStudy.count > 1 {
                            Text(study.modalitiesString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let series = study.numberOfSeries {
                            Label("\(series) series", systemImage: "square.stack")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let images = study.numberOfImages {
                            Label("\(images) images", systemImage: "photo.stack")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

/// A badge displaying a modality code with appropriate styling.
struct ModalityBadge: View {
    let modality: String
    
    var body: some View {
        Text(modality)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(modalityColor.opacity(0.2))
            .foregroundStyle(modalityColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private var modalityColor: Color {
        switch modality.uppercased() {
        case "CT": return .blue
        case "MR", "MRI": return .purple
        case "US": return .cyan
        case "XA", "CR", "DX": return .orange
        case "NM", "PT", "PET": return .green
        case "MG": return .pink
        case "RF": return .yellow
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        StudyListView(
            server: .sample,
            patient: PatientDisplayModel.sampleList[0]
        )
    }
    .environment(AppState())
}

#Preview("With Studies") {
    let appState = AppState()
    appState.studyResults = StudyDisplayModel.sampleList
    
    return NavigationStack {
        StudyListView(
            server: .sample,
            patient: PatientDisplayModel.sampleList[0]
        )
    }
    .environment(appState)
}
