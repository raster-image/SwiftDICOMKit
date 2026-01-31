// ServerConfigView.swift
// DICOMViewer
//
// View for adding or editing PACS server configurations
//

import SwiftUI

/// Mode for the server configuration view.
enum ServerConfigMode {
    case add
    case edit(PACSServer)
    
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
    
    var title: String {
        switch self {
        case .add: return "Add Server"
        case .edit: return "Edit Server"
        }
    }
    
    var saveButtonTitle: String {
        switch self {
        case .add: return "Add"
        case .edit: return "Save"
        }
    }
}

/// View for configuring a PACS server connection.
struct ServerConfigView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: ServerConfigMode
    let onSave: (PACSServer) -> Void
    
    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var calledAETitle: String
    @State private var callingAETitle: String
    @State private var useTLS: Bool
    @State private var timeout: Double
    @State private var isDefault: Bool
    
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?
    @State private var validationErrors: [String] = []
    
    init(mode: ServerConfigMode, onSave: @escaping (PACSServer) -> Void) {
        self.mode = mode
        self.onSave = onSave
        
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _host = State(initialValue: "")
            _port = State(initialValue: "104")
            _calledAETitle = State(initialValue: "")
            _callingAETitle = State(initialValue: "DICOMVIEWER")
            _useTLS = State(initialValue: false)
            _timeout = State(initialValue: 60)
            _isDefault = State(initialValue: false)
        case .edit(let server):
            _name = State(initialValue: server.name)
            _host = State(initialValue: server.host)
            _port = State(initialValue: String(server.port))
            _calledAETitle = State(initialValue: server.calledAETitle)
            _callingAETitle = State(initialValue: server.callingAETitle)
            _useTLS = State(initialValue: server.useTLS)
            _timeout = State(initialValue: server.timeout)
            _isDefault = State(initialValue: server.isDefault)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Server Name", text: $name)
                        .textContentType(.organizationName)
                    
                    TextField("Host/IP Address", text: $host)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    
                    TextField("Port", text: $port)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                
                Section("AE Titles") {
                    TextField("Called AE (Remote PACS)", text: $calledAETitle)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .onChange(of: calledAETitle) { _, newValue in
                            calledAETitle = String(newValue.uppercased().prefix(16))
                        }
                    
                    TextField("Calling AE (This App)", text: $callingAETitle)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .onChange(of: callingAETitle) { _, newValue in
                            callingAETitle = String(newValue.uppercased().prefix(16))
                        }
                }
                
                Section("Connection") {
                    Toggle("Use TLS", isOn: $useTLS)
                    
                    VStack(alignment: .leading) {
                        Text("Timeout: \(Int(timeout)) seconds")
                        Slider(value: $timeout, in: 10...300, step: 10)
                    }
                }
                
                Section("Options") {
                    Toggle("Set as Default", isOn: $isDefault)
                }
                
                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Testing...")
                            } else {
                                Image(systemName: "network")
                                Text("Test Connection")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isTestingConnection || !canTestConnection)
                    
                    if let status = connectionStatus {
                        connectionStatusView(status)
                    }
                }
                
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.saveButtonTitle) {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    @ViewBuilder
    private func connectionStatusView(_ status: ConnectionStatus) -> some View {
        if status.success {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text("Connection Successful")
                        .font(.subheadline)
                    if let responseTime = status.responseTimeMs {
                        Text("Response time: \(Int(responseTime))ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading) {
                    Text("Connection Failed")
                        .font(.subheadline)
                    if let error = status.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var canTestConnection: Bool {
        !host.isEmpty && !port.isEmpty && !calledAETitle.isEmpty && !callingAETitle.isEmpty
    }
    
    private var isValid: Bool {
        validate().isEmpty
    }
    
    private func validate() -> [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Server name is required")
        }
        
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Host address is required")
        }
        
        if let portNumber = UInt16(port), portNumber > 0 {
            // Valid port
        } else {
            errors.append("Invalid port number")
        }
        
        if calledAETitle.isEmpty {
            errors.append("Called AE Title is required")
        }
        
        if callingAETitle.isEmpty {
            errors.append("Calling AE Title is required")
        }
        
        return errors
    }
    
    private func testConnection() {
        connectionStatus = nil
        isTestingConnection = true
        
        let server = buildServer()
        
        Task {
            let status = await ConnectionTestService.shared.testConnection(to: server)
            await MainActor.run {
                connectionStatus = status
                isTestingConnection = false
            }
        }
    }
    
    private func buildServer() -> PACSServer {
        PACSServer(
            id: existingServerID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: UInt16(port) ?? 104,
            calledAETitle: calledAETitle,
            callingAETitle: callingAETitle,
            useTLS: useTLS,
            timeout: timeout,
            isDefault: isDefault
        )
    }
    
    private var existingServerID: UUID? {
        if case .edit(let server) = mode {
            return server.id
        }
        return nil
    }
    
    private func save() {
        validationErrors = validate()
        
        guard validationErrors.isEmpty else { return }
        
        let server = buildServer()
        onSave(server)
        dismiss()
    }
}

#Preview("Add Server") {
    ServerConfigView(mode: .add) { _ in }
}

#Preview("Edit Server") {
    ServerConfigView(mode: .edit(PACSServer.sample)) { _ in }
}
