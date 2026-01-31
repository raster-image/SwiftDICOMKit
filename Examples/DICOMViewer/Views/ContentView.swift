// ContentView.swift
// DICOMViewer
//
// Main content view with navigation structure
//

import SwiftUI

/// The main content view for the DICOMViewer application.
///
/// Provides the root navigation structure and displays the server list
/// as the initial view.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationStack(path: $state.navigationPath) {
            ServerListView()
                .navigationDestination(for: AppScreen.self) { screen in
                    destinationView(for: screen)
                }
        }
        .alert("Error", isPresented: $state.showError) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            if let message = appState.errorMessage {
                Text(message)
            }
        }
    }
    
    /// Returns the appropriate view for a navigation destination.
    @ViewBuilder
    private func destinationView(for screen: AppScreen) -> some View {
        switch screen {
        case .serverList:
            ServerListView()
        case .patientSearch(let server):
            PatientSearchView(server: server)
        case .studyList(let server, let patient):
            StudyListView(server: server, patient: patient)
        case .seriesList(let server, let study):
            SeriesListView(server: server, study: study)
        case .imageViewer(let server, let series):
            // Placeholder for image viewer (Phase 2)
            Text("Image Viewer - Coming Soon")
                .navigationTitle("Images")
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
