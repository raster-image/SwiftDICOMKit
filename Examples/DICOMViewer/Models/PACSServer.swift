// PACSServer.swift
// DICOMViewer
//
// PACS Server configuration model for storing connection details
//

import Foundation

/// Represents a PACS (Picture Archiving and Communication System) server configuration.
///
/// This model stores all the necessary information to connect to a DICOM server,
/// including host, port, AE titles, and TLS settings.
public struct PACSServer: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this server configuration
    public var id: UUID
    
    /// Display name for the server (e.g., "Main PACS", "Radiology Archive")
    public var name: String
    
    /// Hostname or IP address of the PACS server
    public var host: String
    
    /// Port number for DICOM communication (default: 104 or 11112)
    public var port: UInt16
    
    /// Called AE Title - the remote PACS server's Application Entity title
    public var calledAETitle: String
    
    /// Calling AE Title - this application's AE title for identification
    public var callingAETitle: String
    
    /// Whether to use TLS for secure communication
    public var useTLS: Bool
    
    /// Connection timeout in seconds
    public var timeout: TimeInterval
    
    /// Whether this is the default server for queries
    public var isDefault: Bool
    
    /// Creates a new PACS server configuration.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - name: Display name for the server
    ///   - host: Hostname or IP address
    ///   - port: Port number (default: 104)
    ///   - calledAETitle: Remote PACS AE Title
    ///   - callingAETitle: This application's AE Title
    ///   - useTLS: Enable TLS encryption (default: false)
    ///   - timeout: Connection timeout in seconds (default: 60)
    ///   - isDefault: Whether this is the default server (default: false)
    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: UInt16 = 104,
        calledAETitle: String,
        callingAETitle: String = "DICOMVIEWER",
        useTLS: Bool = false,
        timeout: TimeInterval = 60,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.calledAETitle = calledAETitle
        self.callingAETitle = callingAETitle
        self.useTLS = useTLS
        self.timeout = timeout
        self.isDefault = isDefault
    }
}

// MARK: - Validation

extension PACSServer {
    /// Validates the server configuration.
    ///
    /// - Returns: An array of validation error messages, empty if valid.
    public func validate() -> [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Server name is required")
        }
        
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Host address is required")
        }
        
        if port == 0 {
            errors.append("Port must be greater than 0")
        }
        
        if calledAETitle.isEmpty {
            errors.append("Called AE Title is required")
        } else if calledAETitle.count > 16 {
            errors.append("Called AE Title must be 16 characters or less")
        }
        
        if callingAETitle.isEmpty {
            errors.append("Calling AE Title is required")
        } else if callingAETitle.count > 16 {
            errors.append("Calling AE Title must be 16 characters or less")
        }
        
        return errors
    }
    
    /// Whether this server configuration is valid.
    public var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Sample Data

extension PACSServer {
    /// A sample server configuration for testing purposes.
    public static var sample: PACSServer {
        PACSServer(
            name: "Sample PACS",
            host: "pacs.example.com",
            port: 11112,
            calledAETitle: "SAMPLEPACS",
            callingAETitle: "DICOMVIEWER"
        )
    }
    
    /// Sample servers for preview purposes.
    public static var sampleList: [PACSServer] {
        [
            PACSServer(
                name: "Main PACS",
                host: "pacs.hospital.com",
                port: 104,
                calledAETitle: "MAINPACS",
                callingAETitle: "DICOMVIEWER",
                isDefault: true
            ),
            PACSServer(
                name: "Radiology Archive",
                host: "archive.hospital.com",
                port: 11112,
                calledAETitle: "RADARCHIVE",
                callingAETitle: "DICOMVIEWER"
            ),
            PACSServer(
                name: "Research PACS",
                host: "research.university.edu",
                port: 4242,
                calledAETitle: "RESEARCH",
                callingAETitle: "DICOMVIEWER",
                useTLS: true
            )
        ]
    }
}
