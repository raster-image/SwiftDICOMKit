// PACSServerTests.swift
// DICOMViewer Tests
//
// Unit tests for PACSServer model
//

import XCTest
@testable import DICOMCore

// Note: These tests would be part of a separate test target for the DICOMViewer example app.
// The test code below demonstrates the testing patterns that should be used.

/// Tests for the PACSServer model.
final class PACSServerTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        let server = PACSServer(
            name: "Test Server",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        XCTAssertFalse(server.id.uuidString.isEmpty)
        XCTAssertEqual(server.name, "Test Server")
        XCTAssertEqual(server.host, "localhost")
        XCTAssertEqual(server.port, 104)
        XCTAssertEqual(server.calledAETitle, "PACS")
        XCTAssertEqual(server.callingAETitle, "DICOMVIEWER")
        XCTAssertFalse(server.useTLS)
        XCTAssertEqual(server.timeout, 60)
        XCTAssertFalse(server.isDefault)
    }
    
    func testCustomPortInitialization() {
        let server = PACSServer(
            name: "Custom Port Server",
            host: "192.168.1.100",
            port: 11112,
            calledAETitle: "ARCHIVE"
        )
        
        XCTAssertEqual(server.port, 11112)
    }
    
    func testTLSConfiguration() {
        let server = PACSServer(
            name: "Secure Server",
            host: "secure.hospital.com",
            calledAETitle: "SECUREPACS",
            useTLS: true
        )
        
        XCTAssertTrue(server.useTLS)
    }
    
    // MARK: - Validation Tests
    
    func testValidServerConfiguration() {
        let server = PACSServer(
            name: "Valid Server",
            host: "pacs.hospital.com",
            port: 104,
            calledAETitle: "PACS",
            callingAETitle: "CLIENT"
        )
        
        XCTAssertTrue(server.isValid)
        XCTAssertTrue(server.validate().isEmpty)
    }
    
    func testEmptyNameValidation() {
        let server = PACSServer(
            name: "",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        let errors = server.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("name") })
    }
    
    func testEmptyHostValidation() {
        let server = PACSServer(
            name: "Test",
            host: "",
            calledAETitle: "PACS"
        )
        
        let errors = server.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Host") })
    }
    
    func testZeroPortValidation() {
        let server = PACSServer(
            name: "Test",
            host: "localhost",
            port: 0,
            calledAETitle: "PACS"
        )
        
        let errors = server.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Port") })
    }
    
    func testAETitleTooLongValidation() {
        let server = PACSServer(
            name: "Test",
            host: "localhost",
            calledAETitle: "VERYLONGAETITLETHATEXCEEDS16"
        )
        
        let errors = server.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("16 characters") })
    }
    
    func testWhitespaceOnlyNameValidation() {
        let server = PACSServer(
            name: "   ",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        let errors = server.validate()
        XCTAssertFalse(errors.isEmpty)
    }
    
    // MARK: - Codable Tests
    
    func testEncodingAndDecoding() throws {
        let originalServer = PACSServer(
            name: "Test Server",
            host: "pacs.hospital.com",
            port: 11112,
            calledAETitle: "PACS",
            callingAETitle: "CLIENT",
            useTLS: true,
            timeout: 90,
            isDefault: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalServer)
        
        let decoder = JSONDecoder()
        let decodedServer = try decoder.decode(PACSServer.self, from: data)
        
        XCTAssertEqual(decodedServer.id, originalServer.id)
        XCTAssertEqual(decodedServer.name, originalServer.name)
        XCTAssertEqual(decodedServer.host, originalServer.host)
        XCTAssertEqual(decodedServer.port, originalServer.port)
        XCTAssertEqual(decodedServer.calledAETitle, originalServer.calledAETitle)
        XCTAssertEqual(decodedServer.callingAETitle, originalServer.callingAETitle)
        XCTAssertEqual(decodedServer.useTLS, originalServer.useTLS)
        XCTAssertEqual(decodedServer.timeout, originalServer.timeout)
        XCTAssertEqual(decodedServer.isDefault, originalServer.isDefault)
    }
    
    // MARK: - Hashable Tests
    
    func testHashableConformance() {
        let server1 = PACSServer(
            name: "Server 1",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        let server2 = PACSServer(
            name: "Server 1",
            host: "localhost",
            calledAETitle: "PACS"
        )
        
        // Different IDs means different hash values (usually)
        XCTAssertNotEqual(server1, server2)
        
        // Same server should equal itself
        XCTAssertEqual(server1, server1)
    }
    
    // MARK: - Sample Data Tests
    
    func testSampleServer() {
        let sample = PACSServer.sample
        
        XCTAssertTrue(sample.isValid)
        XCTAssertFalse(sample.name.isEmpty)
        XCTAssertFalse(sample.host.isEmpty)
    }
    
    func testSampleList() {
        let samples = PACSServer.sampleList
        
        XCTAssertFalse(samples.isEmpty)
        XCTAssertEqual(samples.count, 3)
        
        // All samples should be valid
        for server in samples {
            XCTAssertTrue(server.isValid, "Sample server '\(server.name)' should be valid")
        }
        
        // One should be default
        XCTAssertEqual(samples.filter { $0.isDefault }.count, 1)
    }
}
