// PatientSearchCriteriaTests.swift
// DICOMViewer Tests
//
// Unit tests for PatientSearchCriteria model
//

import XCTest
@testable import DICOMCore

// Note: These tests would be part of a separate test target for the DICOMViewer example app.
// The test code below demonstrates the testing patterns that should be used.

/// Tests for the PatientSearchCriteria model.
final class PatientSearchCriteriaTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        let criteria = PatientSearchCriteria()
        
        XCTAssertTrue(criteria.patientName.isEmpty)
        XCTAssertTrue(criteria.patientID.isEmpty)
        XCTAssertNil(criteria.birthDateFrom)
        XCTAssertNil(criteria.birthDateTo)
        XCTAssertNil(criteria.sex)
        XCTAssertTrue(criteria.accessionNumber.isEmpty)
        XCTAssertTrue(criteria.modality.isEmpty)
        XCTAssertNil(criteria.studyDateFrom)
        XCTAssertNil(criteria.studyDateTo)
    }
    
    func testCustomInitialization() {
        let criteria = PatientSearchCriteria(
            patientName: "SMITH*",
            patientID: "PAT001",
            sex: .male
        )
        
        XCTAssertEqual(criteria.patientName, "SMITH*")
        XCTAssertEqual(criteria.patientID, "PAT001")
        XCTAssertEqual(criteria.sex, .male)
    }
    
    // MARK: - isEmpty Tests
    
    func testIsEmptyWhenDefault() {
        let criteria = PatientSearchCriteria()
        XCTAssertTrue(criteria.isEmpty)
    }
    
    func testIsNotEmptyWithPatientName() {
        let criteria = PatientSearchCriteria(patientName: "SMITH")
        XCTAssertFalse(criteria.isEmpty)
    }
    
    func testIsNotEmptyWithPatientID() {
        let criteria = PatientSearchCriteria(patientID: "123")
        XCTAssertFalse(criteria.isEmpty)
    }
    
    func testIsNotEmptyWithSex() {
        let criteria = PatientSearchCriteria(sex: .female)
        XCTAssertFalse(criteria.isEmpty)
    }
    
    func testIsNotEmptyWithBirthDate() {
        let criteria = PatientSearchCriteria(birthDateFrom: Date())
        XCTAssertFalse(criteria.isEmpty)
    }
    
    // MARK: - Clear Tests
    
    func testClear() {
        var criteria = PatientSearchCriteria(
            patientName: "TEST",
            patientID: "123",
            sex: .male
        )
        
        criteria.clear()
        
        XCTAssertTrue(criteria.isEmpty)
        XCTAssertTrue(criteria.patientName.isEmpty)
        XCTAssertTrue(criteria.patientID.isEmpty)
        XCTAssertNil(criteria.sex)
    }
    
    // MARK: - Date Range Formatting Tests
    
    func testBirthDateRangeStringNil() {
        let criteria = PatientSearchCriteria()
        XCTAssertNil(criteria.birthDateRangeString)
    }
    
    func testBirthDateRangeStringFromOnly() {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        let date = Calendar.current.date(from: components)!
        
        let criteria = PatientSearchCriteria(birthDateFrom: date)
        
        XCTAssertEqual(criteria.birthDateRangeString, "20000101-")
    }
    
    func testBirthDateRangeStringToOnly() {
        var components = DateComponents()
        components.year = 2020
        components.month = 12
        components.day = 31
        let date = Calendar.current.date(from: components)!
        
        let criteria = PatientSearchCriteria(birthDateTo: date)
        
        XCTAssertEqual(criteria.birthDateRangeString, "-20201231")
    }
    
    func testBirthDateRangeStringBoth() {
        var componentsFrom = DateComponents()
        componentsFrom.year = 1980
        componentsFrom.month = 6
        componentsFrom.day = 15
        let dateFrom = Calendar.current.date(from: componentsFrom)!
        
        var componentsTo = DateComponents()
        componentsTo.year = 1990
        componentsTo.month = 12
        componentsTo.day = 31
        let dateTo = Calendar.current.date(from: componentsTo)!
        
        let criteria = PatientSearchCriteria(
            birthDateFrom: dateFrom,
            birthDateTo: dateTo
        )
        
        XCTAssertEqual(criteria.birthDateRangeString, "19800615-19901231")
    }
    
    func testStudyDateRangeString() {
        var componentsFrom = DateComponents()
        componentsFrom.year = 2024
        componentsFrom.month = 1
        componentsFrom.day = 1
        let dateFrom = Calendar.current.date(from: componentsFrom)!
        
        var componentsTo = DateComponents()
        componentsTo.year = 2024
        componentsTo.month = 3
        componentsTo.day = 31
        let dateTo = Calendar.current.date(from: componentsTo)!
        
        let criteria = PatientSearchCriteria(
            studyDateFrom: dateFrom,
            studyDateTo: dateTo
        )
        
        XCTAssertEqual(criteria.studyDateRangeString, "20240101-20240331")
    }
    
    // MARK: - Quick Filter Tests
    
    func testTodayQuickFilter() {
        let criteria = PatientSearchCriteria.today
        
        XCTAssertNotNil(criteria.studyDateFrom)
        XCTAssertNotNil(criteria.studyDateTo)
        
        // Should be today
        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(criteria.studyDateFrom!))
    }
    
    func testThisWeekQuickFilter() {
        let criteria = PatientSearchCriteria.thisWeek
        
        XCTAssertNotNil(criteria.studyDateFrom)
        XCTAssertNotNil(criteria.studyDateTo)
        
        // Study date should be within this week
        let calendar = Calendar.current
        let today = Date()
        let weekOfYear = calendar.component(.weekOfYear, from: today)
        let studyWeek = calendar.component(.weekOfYear, from: criteria.studyDateFrom!)
        
        XCTAssertEqual(weekOfYear, studyWeek)
    }
    
    func testThisMonthQuickFilter() {
        let criteria = PatientSearchCriteria.thisMonth
        
        XCTAssertNotNil(criteria.studyDateFrom)
        XCTAssertNotNil(criteria.studyDateTo)
        
        // Study date should be within this month
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let studyMonth = calendar.component(.month, from: criteria.studyDateFrom!)
        
        XCTAssertEqual(month, studyMonth)
    }
    
    // MARK: - PatientSex Tests
    
    func testPatientSexDisplayNames() {
        XCTAssertEqual(PatientSex.male.displayName, "Male")
        XCTAssertEqual(PatientSex.female.displayName, "Female")
        XCTAssertEqual(PatientSex.other.displayName, "Other")
    }
    
    func testPatientSexRawValues() {
        XCTAssertEqual(PatientSex.male.rawValue, "M")
        XCTAssertEqual(PatientSex.female.rawValue, "F")
        XCTAssertEqual(PatientSex.other.rawValue, "O")
    }
    
    func testPatientSexAllCases() {
        let allCases = PatientSex.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.male))
        XCTAssertTrue(allCases.contains(.female))
        XCTAssertTrue(allCases.contains(.other))
    }
    
    // MARK: - Codable Tests
    
    func testEncodingAndDecoding() throws {
        let original = PatientSearchCriteria(
            patientName: "TEST*",
            patientID: "12345",
            sex: .female,
            modality: "CT"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PatientSearchCriteria.self, from: data)
        
        XCTAssertEqual(decoded.patientName, original.patientName)
        XCTAssertEqual(decoded.patientID, original.patientID)
        XCTAssertEqual(decoded.sex, original.sex)
        XCTAssertEqual(decoded.modality, original.modality)
    }
}
