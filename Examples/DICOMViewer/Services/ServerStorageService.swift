// ServerStorageService.swift
// DICOMViewer
//
// Service for persisting PACS server configurations
//

import Foundation

/// Service for storing and retrieving PACS server configurations.
///
/// Uses UserDefaults for persistence. Server configurations are stored
/// as JSON-encoded data under a specific key.
public final class ServerStorageService: Sendable {
    
    /// Shared instance for convenience.
    public static let shared = ServerStorageService()
    
    /// UserDefaults key for storing servers.
    private let storageKey = "com.dicomviewer.pacsServers"
    
    /// UserDefaults key for storing the default server ID.
    private let defaultServerKey = "com.dicomviewer.defaultServerID"
    
    /// UserDefaults instance to use.
    private let defaults: UserDefaults
    
    /// Creates a new server storage service.
    ///
    /// - Parameter defaults: UserDefaults instance to use (defaults to standard).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    // MARK: - Server Operations
    
    /// Loads all saved PACS servers.
    ///
    /// - Returns: Array of saved server configurations.
    public func loadServers() -> [PACSServer] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        
        do {
            let servers = try JSONDecoder().decode([PACSServer].self, from: data)
            return servers
        } catch {
            print("Failed to decode servers: \(error)")
            return []
        }
    }
    
    /// Saves all PACS servers.
    ///
    /// - Parameter servers: Array of server configurations to save.
    /// - Throws: Encoding error if serialization fails.
    public func saveServers(_ servers: [PACSServer]) throws {
        let data = try JSONEncoder().encode(servers)
        defaults.set(data, forKey: storageKey)
    }
    
    /// Adds a new server configuration.
    ///
    /// - Parameter server: The server to add.
    /// - Throws: Encoding error if serialization fails.
    public func addServer(_ server: PACSServer) throws {
        var servers = loadServers()
        servers.append(server)
        try saveServers(servers)
    }
    
    /// Updates an existing server configuration.
    ///
    /// - Parameter server: The server with updated values.
    /// - Throws: Error if server not found or serialization fails.
    public func updateServer(_ server: PACSServer) throws {
        var servers = loadServers()
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else {
            throw ServerStorageError.serverNotFound(server.id)
        }
        servers[index] = server
        try saveServers(servers)
    }
    
    /// Deletes a server configuration.
    ///
    /// - Parameter id: The ID of the server to delete.
    /// - Throws: Encoding error if serialization fails.
    public func deleteServer(id: UUID) throws {
        var servers = loadServers()
        servers.removeAll { $0.id == id }
        try saveServers(servers)
        
        // Clear default if deleted server was default
        if getDefaultServerID() == id {
            setDefaultServerID(nil)
        }
    }
    
    /// Gets a server by its ID.
    ///
    /// - Parameter id: The server ID to look up.
    /// - Returns: The server if found, nil otherwise.
    public func getServer(id: UUID) -> PACSServer? {
        loadServers().first { $0.id == id }
    }
    
    // MARK: - Default Server
    
    /// Gets the ID of the default server.
    ///
    /// - Returns: The default server's UUID, or nil if not set.
    public func getDefaultServerID() -> UUID? {
        guard let string = defaults.string(forKey: defaultServerKey) else {
            return nil
        }
        return UUID(uuidString: string)
    }
    
    /// Sets the default server.
    ///
    /// - Parameter id: The ID of the server to set as default, or nil to clear.
    public func setDefaultServerID(_ id: UUID?) {
        if let id = id {
            defaults.set(id.uuidString, forKey: defaultServerKey)
        } else {
            defaults.removeObject(forKey: defaultServerKey)
        }
    }
    
    /// Gets the default server configuration.
    ///
    /// - Returns: The default server if set and found, nil otherwise.
    public func getDefaultServer() -> PACSServer? {
        guard let id = getDefaultServerID() else { return nil }
        return getServer(id: id)
    }
    
    /// Marks a server as the default, unmarking any previous default.
    ///
    /// - Parameter id: The ID of the server to set as default.
    /// - Throws: Error if serialization fails.
    public func setAsDefault(id: UUID) throws {
        var servers = loadServers()
        
        // Update isDefault flags
        for i in servers.indices {
            servers[i].isDefault = (servers[i].id == id)
        }
        
        try saveServers(servers)
        setDefaultServerID(id)
    }
    
    // MARK: - Utility
    
    /// Deletes all saved servers.
    public func deleteAllServers() {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: defaultServerKey)
    }
    
    /// Checks if any servers are saved.
    ///
    /// - Returns: True if at least one server is saved.
    public var hasServers: Bool {
        !loadServers().isEmpty
    }
}

// MARK: - Errors

/// Errors that can occur during server storage operations.
public enum ServerStorageError: Error, LocalizedError {
    case serverNotFound(UUID)
    case encodingFailed(Error)
    case decodingFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .serverNotFound(let id):
            return "Server with ID \(id) not found"
        case .encodingFailed(let error):
            return "Failed to encode servers: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode servers: \(error.localizedDescription)"
        }
    }
}
