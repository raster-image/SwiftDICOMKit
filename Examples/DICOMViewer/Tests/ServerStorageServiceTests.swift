// ServerStorageServiceTests.swift
// DICOMViewer Tests
//
// Unit tests for ServerStorageService
//

import XCTest
@testable import DICOMCore

// Note: These tests would be part of a separate test target for the DICOMViewer example app.
// The test code below demonstrates the testing patterns that should be used.

/// Tests for the ServerStorageService.
final class ServerStorageServiceTests: XCTestCase {
    
    var service: ServerStorageService!
    var testDefaults: UserDefaults!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a unique suite name for testing
        let suiteName = "com.dicomviewer.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        service = ServerStorageService(defaults: testDefaults)
    }
    
    override func tearDownWithError() throws {
        // Clean up test defaults
        testDefaults.removePersistentDomain(forName: testDefaults.volatileDomainNames.first ?? "")
        testDefaults = nil
        service = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Operations Tests
    
    func testLoadServersEmpty() {
        let servers = service.loadServers()
        XCTAssertTrue(servers.isEmpty)
    }
    
    func testAddServer() throws {
        let server = PACSServer(
            name: "Test Server",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        try service.addServer(server)
        
        let loaded = service.loadServers()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Test Server")
    }
    
    func testAddMultipleServers() throws {
        let server1 = PACSServer(name: "Server 1", host: "host1", calledAETitle: "AE1")
        let server2 = PACSServer(name: "Server 2", host: "host2", calledAETitle: "AE2")
        let server3 = PACSServer(name: "Server 3", host: "host3", calledAETitle: "AE3")
        
        try service.addServer(server1)
        try service.addServer(server2)
        try service.addServer(server3)
        
        let loaded = service.loadServers()
        XCTAssertEqual(loaded.count, 3)
    }
    
    func testUpdateServer() throws {
        let server = PACSServer(
            name: "Original Name",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        try service.addServer(server)
        
        // Update the server
        var updatedServer = server
        updatedServer.name = "Updated Name"
        updatedServer.port = 11112
        
        try service.updateServer(updatedServer)
        
        let loaded = service.loadServers()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Updated Name")
        XCTAssertEqual(loaded.first?.port, 11112)
    }
    
    func testUpdateNonexistentServer() {
        let server = PACSServer(
            name: "Nonexistent",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        XCTAssertThrowsError(try service.updateServer(server)) { error in
            XCTAssertTrue(error is ServerStorageError)
        }
    }
    
    func testDeleteServer() throws {
        let server = PACSServer(
            name: "To Delete",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        try service.addServer(server)
        XCTAssertEqual(service.loadServers().count, 1)
        
        try service.deleteServer(id: server.id)
        XCTAssertEqual(service.loadServers().count, 0)
    }
    
    func testDeleteNonexistentServer() throws {
        // Should not throw, just silently succeed
        try service.deleteServer(id: UUID())
        XCTAssertTrue(service.loadServers().isEmpty)
    }
    
    // MARK: - Get Server Tests
    
    func testGetServerById() throws {
        let server = PACSServer(
            name: "Test",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        try service.addServer(server)
        
        let retrieved = service.getServer(id: server.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test")
    }
    
    func testGetServerByIdNotFound() {
        let retrieved = service.getServer(id: UUID())
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Default Server Tests
    
    func testSetDefaultServer() throws {
        let server1 = PACSServer(name: "Server 1", host: "host1", calledAETitle: "AE1")
        let server2 = PACSServer(name: "Server 2", host: "host2", calledAETitle: "AE2")
        
        try service.addServer(server1)
        try service.addServer(server2)
        
        try service.setAsDefault(id: server2.id)
        
        let defaultServer = service.getDefaultServer()
        XCTAssertNotNil(defaultServer)
        XCTAssertEqual(defaultServer?.id, server2.id)
        
        // Check isDefault flag is set correctly
        let loaded = service.loadServers()
        let server1Loaded = loaded.first { $0.id == server1.id }
        let server2Loaded = loaded.first { $0.id == server2.id }
        
        XCTAssertFalse(server1Loaded?.isDefault ?? true)
        XCTAssertTrue(server2Loaded?.isDefault ?? false)
    }
    
    func testGetDefaultServerWhenNoneSet() {
        XCTAssertNil(service.getDefaultServer())
        XCTAssertNil(service.getDefaultServerID())
    }
    
    func testClearDefaultServer() throws {
        let server = PACSServer(
            name: "Server",
            host: "host",
            calledAETitle: "AE",
            isDefault: true
        )
        
        try service.addServer(server)
        try service.setAsDefault(id: server.id)
        
        XCTAssertNotNil(service.getDefaultServer())
        
        service.setDefaultServerID(nil)
        
        XCTAssertNil(service.getDefaultServerID())
    }
    
    func testDeleteDefaultServerClearsDefault() throws {
        let server = PACSServer(
            name: "Default",
            host: "host",
            calledAETitle: "AE"
        )
        
        try service.addServer(server)
        try service.setAsDefault(id: server.id)
        
        XCTAssertNotNil(service.getDefaultServerID())
        
        try service.deleteServer(id: server.id)
        
        XCTAssertNil(service.getDefaultServerID())
    }
    
    // MARK: - Utility Tests
    
    func testHasServersEmpty() {
        XCTAssertFalse(service.hasServers)
    }
    
    func testHasServersWithServer() throws {
        let server = PACSServer(
            name: "Test",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        try service.addServer(server)
        
        XCTAssertTrue(service.hasServers)
    }
    
    func testDeleteAllServers() throws {
        let server1 = PACSServer(name: "Server 1", host: "host1", calledAETitle: "AE1")
        let server2 = PACSServer(name: "Server 2", host: "host2", calledAETitle: "AE2")
        
        try service.addServer(server1)
        try service.addServer(server2)
        try service.setAsDefault(id: server1.id)
        
        XCTAssertEqual(service.loadServers().count, 2)
        XCTAssertNotNil(service.getDefaultServerID())
        
        service.deleteAllServers()
        
        XCTAssertEqual(service.loadServers().count, 0)
        XCTAssertNil(service.getDefaultServerID())
    }
    
    // MARK: - Persistence Tests
    
    func testServersPersistAcrossInstances() throws {
        let server = PACSServer(
            name: "Persistent",
            host: "localhost",
            port: 12345,
            calledAETitle: "TEST"
        )
        
        try service.addServer(server)
        
        // Create a new service instance with the same defaults
        let newService = ServerStorageService(defaults: testDefaults)
        let loaded = newService.loadServers()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Persistent")
        XCTAssertEqual(loaded.first?.port, 12345)
    }
}
