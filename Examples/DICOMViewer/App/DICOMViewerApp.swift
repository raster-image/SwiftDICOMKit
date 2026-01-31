// DICOMViewerApp.swift
// DICOMViewer
//
// Main entry point for the DICOMViewer example application
//

import SwiftUI

/// The main entry point for the DICOMViewer application.
///
/// This is an example application demonstrating the capabilities of DICOMKit
/// for browsing and viewing DICOM images from PACS servers.
@main
struct DICOMViewerApp: App {
    /// The global application state.
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Server") {
                    // TODO: Add new server action
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
        }
        #endif
    }
}

#if os(macOS)
/// Settings view for macOS preferences.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ServerSettingsView()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
        }
        .frame(width: 500, height: 300)
    }
}

/// General settings view.
struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General Settings")
                .font(.headline)
            
            Text("Configure general application preferences here.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

/// Server settings view.
struct ServerSettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            Text("PACS Servers")
                .font(.headline)
            
            List {
                ForEach(appState.servers) { server in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(server.name)
                                .font(.body)
                            Text("\(server.host):\(server.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if server.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
#endif
