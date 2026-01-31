// ServerListView.swift
// DICOMViewer
//
// View for displaying and managing PACS server configurations
//

import SwiftUI

/// Displays a list of configured PACS servers.
///
/// Provides functionality to add, edit, delete, and test connections to servers.
struct ServerListView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddServer = false
    @State private var serverToEdit: PACSServer?
    @State private var serverToDelete: PACSServer?
    
    var body: some View {
        List {
            if appState.servers.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add a PACS server to get started.")
                )
            } else {
                ForEach(appState.servers) { server in
                    ServerRowView(
                        server: server,
                        connectionStatus: appState.connectionStatuses[server.id],
                        isTestingConnection: appState.isTestingConnection,
                        onTap: {
                            appState.navigateToPatientSearch(server: server)
                        },
                        onTestConnection: {
                            Task {
                                await appState.testConnection(to: server)
                            }
                        },
                        onEdit: {
                            serverToEdit = server
                        },
                        onDelete: {
                            serverToDelete = server
                        },
                        onSetDefault: {
                            appState.setDefaultServer(server)
                        }
                    )
                }
            }
        }
        .navigationTitle("PACS Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddServer = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddServer) {
            ServerConfigView(mode: .add) { server in
                appState.addServer(server)
            }
        }
        .sheet(item: $serverToEdit) { server in
            ServerConfigView(mode: .edit(server)) { updatedServer in
                appState.updateServer(updatedServer)
            }
        }
        .alert("Delete Server", isPresented: .init(
            get: { serverToDelete != nil },
            set: { if !$0 { serverToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                serverToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let server = serverToDelete {
                    appState.deleteServer(server)
                }
                serverToDelete = nil
            }
        } message: {
            if let server = serverToDelete {
                Text("Are you sure you want to delete '\(server.name)'?")
            }
        }
    }
}

/// A row displaying a single PACS server.
struct ServerRowView: View {
    let server: PACSServer
    let connectionStatus: ConnectionStatus?
    let isTestingConnection: Bool
    let onTap: () -> Void
    let onTestConnection: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSetDefault: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(server.name)
                            .font(.headline)
                        
                        if server.isDefault {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundStyle(.accent)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text("\(server.host):\(server.port)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("AE: \(server.calledAETitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if server.useTLS {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Spacer()
                
                connectionStatusView
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTestConnection()
            } label: {
                Label("Test Connection", systemImage: "network")
            }
            
            if !server.isDefault {
                Button {
                    onSetDefault()
                } label: {
                    Label("Set as Default", systemImage: "star")
                }
            }
            
            Divider()
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                onTestConnection()
            } label: {
                Label("Test", systemImage: "network")
            }
            .tint(.blue)
        }
    }
    
    @ViewBuilder
    private var connectionStatusView: some View {
        if isTestingConnection {
            ProgressView()
                .controlSize(.small)
        } else if let status = connectionStatus {
            if status.success {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if let responseTime = status.responseTimeMs {
                        Text("\(Int(responseTime))ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ServerListView()
    }
    .environment(AppState())
}

#Preview("With Servers") {
    let appState = AppState()
    appState.servers = PACSServer.sampleList
    
    return NavigationStack {
        ServerListView()
    }
    .environment(appState)
}
