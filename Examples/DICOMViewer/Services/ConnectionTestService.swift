// ConnectionTestService.swift
// DICOMViewer
//
// Service for testing PACS server connections using C-ECHO
//

import Foundation
import DICOMNetwork

/// Service for testing PACS server connections using C-ECHO verification.
///
/// This service wraps the DICOMNetwork verification functionality to provide
/// a simple interface for testing connectivity to PACS servers.
public actor ConnectionTestService {
    
    /// Shared instance for convenience.
    public static let shared = ConnectionTestService()
    
    /// Creates a new connection test service.
    public init() {}
    
    /// Tests the connection to a PACS server using C-ECHO.
    ///
    /// C-ECHO is the DICOM verification service that tests basic connectivity
    /// and association negotiation without transferring any patient data.
    ///
    /// - Parameter server: The PACS server configuration to test.
    /// - Returns: The connection status result.
    public func testConnection(to server: PACSServer) async -> ConnectionStatus {
        let startTime = Date()
        
        do {
            // Validate server configuration first
            let validationErrors = server.validate()
            if !validationErrors.isEmpty {
                return .failure("Invalid configuration: \(validationErrors.joined(separator: ", "))")
            }
            
            // Perform C-ECHO verification
            try await VerificationService.verify(
                host: server.host,
                port: server.port,
                callingAE: server.callingAETitle,
                calledAE: server.calledAETitle
            )
            
            // Calculate response time
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            
            return .success(responseTimeMs: responseTime)
            
        } catch let error as DICOMNetworkError {
            return .failure(formatError(error, for: server))
        } catch {
            return .failure("Connection failed: \(error.localizedDescription)")
        }
    }
    
    /// Formats a DICOMNetworkError into a user-friendly message.
    private func formatError(_ error: DICOMNetworkError, for server: PACSServer) -> String {
        switch error {
        case .connectionFailed(let underlying):
            return "Connection refused to \(server.host):\(server.port). " +
                   "Please verify the host and port are correct. (\(underlying.localizedDescription))"
            
        case .timeout:
            return "Connection timed out after \(Int(server.timeout)) seconds. " +
                   "The server may be unreachable or slow to respond."
            
        case .associationRejected(let result, let source, let reason):
            return formatAssociationRejection(result: result, source: source, reason: reason, server: server)
            
        case .associationAborted:
            return "Connection was aborted by the remote server. " +
                   "This may indicate a configuration mismatch."
            
        case .invalidPDU:
            return "Received invalid response from server. " +
                   "The server may not be a valid DICOM server."
            
        case .operationFailed(let message):
            return "Operation failed: \(message)"
            
        default:
            return "Connection failed: \(error.localizedDescription)"
        }
    }
    
    /// Formats association rejection details.
    private func formatAssociationRejection(
        result: UInt8,
        source: UInt8,
        reason: UInt8,
        server: PACSServer
    ) -> String {
        var message = "Connection rejected by \(server.calledAETitle). "
        
        // Interpret rejection reason based on source
        switch source {
        case 1: // Service User
            switch reason {
            case 1: message += "No reason given."
            case 2: message += "Application context not supported."
            case 3: message += "Calling AE Title '\(server.callingAETitle)' not recognized."
            case 7: message += "Called AE Title '\(server.calledAETitle)' not recognized."
            default: message += "Reason code: \(reason)"
            }
        case 2: // Service Provider (ACSE)
            switch reason {
            case 1: message += "No reason given."
            case 2: message += "Protocol version not supported."
            default: message += "Provider reason: \(reason)"
            }
        case 3: // Service Provider (Presentation)
            switch reason {
            case 1: message += "Temporary congestion."
            case 2: message += "Local limit exceeded."
            default: message += "Presentation reason: \(reason)"
            }
        default:
            message += "Unknown rejection (source: \(source), reason: \(reason))"
        }
        
        return message
    }
}

// MARK: - PACSConnectionError

/// Categorized errors for PACS connections.
public enum PACSConnectionError: Error, LocalizedError {
    case connectionRefused(host: String, port: UInt16)
    case timeout(seconds: Int)
    case aeRejected(aeTitle: String)
    case tlsError(underlying: Error)
    case invalidResponse
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .connectionRefused(let host, let port):
            return "Connection refused to \(host):\(port)"
        case .timeout(let seconds):
            return "Connection timed out after \(seconds) seconds"
        case .aeRejected(let aeTitle):
            return "AE Title '\(aeTitle)' was rejected by the server"
        case .tlsError(let error):
            return "TLS error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received invalid response from server"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    /// Suggested recovery action for this error.
    public var recoverySuggestion: String? {
        switch self {
        case .connectionRefused:
            return "Verify the host address and port number are correct, and that the PACS server is running."
        case .timeout:
            return "Check your network connection and try again. You may need to increase the timeout setting."
        case .aeRejected:
            return "Verify the AE Titles are configured correctly on both sides."
        case .tlsError:
            return "Check TLS certificate configuration and ensure the server supports secure connections."
        case .invalidResponse:
            return "Ensure you are connecting to a valid DICOM server."
        case .unknown:
            return "Try checking your network connection and server configuration."
        }
    }
}
