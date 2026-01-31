// AppState.swift
// DICOMViewer
//
// Global application state management using @Observable macro
//

import Foundation
import SwiftUI

/// Represents the current screen in the app navigation.
public enum AppScreen: Hashable, Sendable {
    /// Server list and configuration
    case serverList
    /// Patient search form
    case patientSearch(server: PACSServer)
    /// Study list for a selected patient
    case studyList(server: PACSServer, patient: PatientDisplayModel)
    /// Series list for a selected study
    case seriesList(server: PACSServer, study: StudyDisplayModel)
    /// Image viewer for a selected series
    case imageViewer(server: PACSServer, series: SeriesDisplayModel)
}

/// Global application state using the @Observable macro.
///
/// This class manages the application's navigation state, selected server,
/// and other shared state that needs to be accessible across the app.
@MainActor
@Observable
public final class AppState {
    
    // MARK: - Navigation
    
    /// The current navigation path for push navigation.
    public var navigationPath: [AppScreen] = []
    
    // MARK: - Servers
    
    /// All configured PACS servers.
    public var servers: [PACSServer] = []
    
    /// The currently selected server for queries.
    public var selectedServer: PACSServer?
    
    /// Connection status for each server (by ID).
    public var connectionStatuses: [UUID: ConnectionStatus] = [:]
    
    // MARK: - Search State
    
    /// Current search criteria.
    public var searchCriteria = PatientSearchCriteria()
    
    /// Search results - patients.
    public var patientResults: [PatientDisplayModel] = []
    
    /// Selected patient for drill-down.
    public var selectedPatient: PatientDisplayModel?
    
    /// Studies for selected patient.
    public var studyResults: [StudyDisplayModel] = []
    
    /// Selected study for drill-down.
    public var selectedStudy: StudyDisplayModel?
    
    /// Series for selected study.
    public var seriesResults: [SeriesDisplayModel] = []
    
    // MARK: - Loading State
    
    /// Whether a search is in progress.
    public var isSearching = false
    
    /// Whether a connection test is in progress.
    public var isTestingConnection = false
    
    /// Whether studies are loading.
    public var isLoadingStudies = false
    
    /// Whether series are loading.
    public var isLoadingSeries = false
    
    // MARK: - Error State
    
    /// Current error message to display.
    public var errorMessage: String?
    
    /// Whether to show the error alert.
    public var showError = false
    
    // MARK: - Initialization
    
    /// Creates a new app state instance.
    public init() {
        loadServers()
    }
    
    // MARK: - Server Management
    
    /// Loads servers from persistent storage.
    public func loadServers() {
        servers = ServerStorageService.shared.loadServers()
        
        // Set selected server to default if available
        if let defaultServer = ServerStorageService.shared.getDefaultServer() {
            selectedServer = defaultServer
        } else if let firstServer = servers.first {
            selectedServer = firstServer
        }
    }
    
    /// Saves a new server.
    public func addServer(_ server: PACSServer) {
        do {
            try ServerStorageService.shared.addServer(server)
            servers.append(server)
            
            // Set as selected if it's the first server
            if servers.count == 1 {
                selectedServer = server
            }
        } catch {
            showError(message: "Failed to save server: \(error.localizedDescription)")
        }
    }
    
    /// Updates an existing server.
    public func updateServer(_ server: PACSServer) {
        do {
            try ServerStorageService.shared.updateServer(server)
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index] = server
            }
            
            // Update selected server if it's the one being updated
            if selectedServer?.id == server.id {
                selectedServer = server
            }
        } catch {
            showError(message: "Failed to update server: \(error.localizedDescription)")
        }
    }
    
    /// Deletes a server.
    public func deleteServer(_ server: PACSServer) {
        do {
            try ServerStorageService.shared.deleteServer(id: server.id)
            servers.removeAll { $0.id == server.id }
            connectionStatuses.removeValue(forKey: server.id)
            
            // Clear selected server if it was deleted
            if selectedServer?.id == server.id {
                selectedServer = servers.first
            }
        } catch {
            showError(message: "Failed to delete server: \(error.localizedDescription)")
        }
    }
    
    /// Sets a server as the default.
    public func setDefaultServer(_ server: PACSServer) {
        do {
            try ServerStorageService.shared.setAsDefault(id: server.id)
            
            // Update local state
            for i in servers.indices {
                servers[i].isDefault = (servers[i].id == server.id)
            }
        } catch {
            showError(message: "Failed to set default server: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Connection Testing
    
    /// Tests connection to a server.
    public func testConnection(to server: PACSServer) async {
        isTestingConnection = true
        let status = await ConnectionTestService.shared.testConnection(to: server)
        connectionStatuses[server.id] = status
        isTestingConnection = false
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigates to patient search for a server.
    public func navigateToPatientSearch(server: PACSServer) {
        selectedServer = server
        navigationPath.append(.patientSearch(server: server))
    }
    
    /// Navigates to study list for a patient.
    public func navigateToStudyList(patient: PatientDisplayModel) {
        guard let server = selectedServer else { return }
        selectedPatient = patient
        navigationPath.append(.studyList(server: server, patient: patient))
    }
    
    /// Navigates to series list for a study.
    public func navigateToSeriesList(study: StudyDisplayModel) {
        guard let server = selectedServer else { return }
        selectedStudy = study
        navigationPath.append(.seriesList(server: server, study: study))
    }
    
    /// Navigates back.
    public func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
    
    /// Navigates to root.
    public func navigateToRoot() {
        navigationPath.removeAll()
    }
    
    // MARK: - Search
    
    /// Searches for patients with current criteria.
    public func searchPatients() async {
        guard let server = selectedServer else {
            showError(message: "No server selected")
            return
        }
        
        isSearching = true
        patientResults = []
        
        do {
            patientResults = try await PACSQueryService.shared.findPatients(
                on: server,
                matching: searchCriteria
            )
        } catch {
            showError(message: "Search failed: \(error.localizedDescription)")
        }
        
        isSearching = false
    }
    
    /// Loads studies for the selected patient.
    public func loadStudies() async {
        guard let server = selectedServer,
              let patient = selectedPatient else {
            return
        }
        
        isLoadingStudies = true
        studyResults = []
        
        do {
            studyResults = try await PACSQueryService.shared.findStudies(
                on: server,
                forPatientID: patient.patientID
            )
        } catch {
            showError(message: "Failed to load studies: \(error.localizedDescription)")
        }
        
        isLoadingStudies = false
    }
    
    /// Loads series for the selected study.
    public func loadSeries() async {
        guard let server = selectedServer,
              let study = selectedStudy else {
            return
        }
        
        isLoadingSeries = true
        seriesResults = []
        
        do {
            seriesResults = try await PACSQueryService.shared.findSeries(
                on: server,
                forStudyInstanceUID: study.studyInstanceUID
            )
        } catch {
            showError(message: "Failed to load series: \(error.localizedDescription)")
        }
        
        isLoadingSeries = false
    }
    
    // MARK: - Error Handling
    
    /// Shows an error message.
    public func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    /// Clears the current error.
    public func clearError() {
        errorMessage = nil
        showError = false
    }
}
