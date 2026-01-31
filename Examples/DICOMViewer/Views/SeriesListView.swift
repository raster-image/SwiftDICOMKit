// SeriesListView.swift
// DICOMViewer
//
// View for displaying series within a selected study
//

import SwiftUI

/// Displays a list of series for a selected study.
///
/// Shows series details including modality, description, body part,
/// and image count. This is the final level before image viewing (Phase 2).
struct SeriesListView: View {
    @Environment(AppState.self) private var appState
    let server: PACSServer
    let study: StudyDisplayModel
    
    @State private var sortOrder: SeriesSortOrder = .number
    @State private var modalityFilter: String?
    
    var body: some View {
        List {
            // Study header
            Section {
                StudyHeaderView(study: study)
            }
            
            // Filter and sort options
            Section {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SeriesSortOrder.allCases, id: \.self) { order in
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
            
            // Series list
            if appState.isLoadingSeries {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading series...")
                        Spacer()
                    }
                    .padding()
                }
            } else if filteredSeries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Series",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("No series found in this study.")
                    )
                }
            } else {
                Section("Series (\(filteredSeries.count))") {
                    ForEach(sortedSeries) { series in
                        SeriesRowView(series: series) {
                            // Navigate to image viewer (Phase 2)
                            appState.navigationPath.append(
                                .imageViewer(server: server, series: series)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Series")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadSeries()
        }
        .refreshable {
            await loadSeries()
        }
    }
    
    private var filteredSeries: [SeriesDisplayModel] {
        guard let filter = modalityFilter else {
            return appState.seriesResults
        }
        return appState.seriesResults.filter { $0.modality == filter }
    }
    
    private var sortedSeries: [SeriesDisplayModel] {
        switch sortOrder {
        case .number:
            return filteredSeries.sorted { ($0.seriesNumber ?? 0) < ($1.seriesNumber ?? 0) }
        case .modality:
            return filteredSeries.sorted { $0.modality < $1.modality }
        case .description:
            return filteredSeries.sorted { $0.seriesDescription < $1.seriesDescription }
        case .imageCount:
            return filteredSeries.sorted { ($0.numberOfImages ?? 0) > ($1.numberOfImages ?? 0) }
        }
    }
    
    private var availableModalities: [String] {
        let modalities = appState.seriesResults.map { $0.modality }.filter { !$0.isEmpty }
        return Array(Set(modalities)).sorted()
    }
    
    private func loadSeries() async {
        appState.selectedStudy = study
        await appState.loadSeries()
    }
}

/// Sort order options for series.
enum SeriesSortOrder: CaseIterable {
    case number
    case modality
    case description
    case imageCount
    
    var displayName: String {
        switch self {
        case .number: return "Series Number"
        case .modality: return "Modality"
        case .description: return "Description"
        case .imageCount: return "Image Count"
        }
    }
}

/// Header view showing study information.
struct StudyHeaderView: View {
    let study: StudyDisplayModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let modality = study.modalitiesInStudy.first {
                    ModalityBadge(modality: modality)
                }
                
                VStack(alignment: .leading) {
                    Text(study.studyDescription.isEmpty ? "Untitled Study" : study.studyDescription)
                        .font(.headline)
                    if let date = study.formattedStudyDate {
                        Text(date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            HStack(spacing: 16) {
                if !study.accessionNumber.isEmpty {
                    Label(study.accessionNumber, systemImage: "number")
                        .font(.caption)
                }
                
                if !study.referringPhysician.isEmpty {
                    Label(study.referringPhysician, systemImage: "person")
                        .font(.caption)
                }
                
                if let series = study.numberOfSeries {
                    Label("\(series) series", systemImage: "square.stack")
                        .font(.caption)
                }
                
                if let images = study.numberOfImages {
                    Label("\(images) images", systemImage: "photo.stack")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// A row displaying a single series.
struct SeriesRowView: View {
    let series: SeriesDisplayModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Series number badge
                if let number = series.seriesNumber {
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Series description
                    Text(series.displayTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Modality and body part
                    HStack(spacing: 8) {
                        if !series.modality.isEmpty {
                            ModalityBadge(modality: series.modality)
                        }
                        
                        if !series.bodyPartExamined.isEmpty {
                            Text(series.bodyPartExamined)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Image count
                    if let imageCount = series.imageCountString {
                        Label(imageCount, systemImage: "photo.stack")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Preview placeholder (Phase 2)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SeriesListView(
            server: .sample,
            study: StudyDisplayModel.sampleList[0]
        )
    }
    .environment(AppState())
}

#Preview("With Series") {
    let appState = AppState()
    appState.seriesResults = SeriesDisplayModel.sampleList
    
    return NavigationStack {
        SeriesListView(
            server: .sample,
            study: StudyDisplayModel.sampleList[0]
        )
    }
    .environment(appState)
}
