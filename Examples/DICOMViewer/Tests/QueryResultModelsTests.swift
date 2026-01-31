// QueryResultModelsTests.swift
// DICOMViewer Tests
//
// Unit tests for Query Result Display Models
//

import XCTest
@testable import DICOMCore

// Note: These tests would be part of a separate test target for the DICOMViewer example app.
// The test code below demonstrates the testing patterns that should be used.

/// Tests for the PatientDisplayModel.
final class PatientDisplayModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testBasicInitialization() {
        let patient = PatientDisplayModel(
            patientName: "SMITH^JOHN",
            patientID: "PAT001"
        )
        
        XCTAssertFalse(patient.id.isEmpty)
        XCTAssertEqual(patient.patientName, "SMITH^JOHN")
        XCTAssertEqual(patient.patientID, "PAT001")
        XCTAssertNil(patient.birthDate)
        XCTAssertNil(patient.sex)
        XCTAssertNil(patient.numberOfStudies)
    }
    
    func testFullInitialization() {
        let birthDate = Calendar.current.date(byAdding: .year, value: -45, to: Date())!
        
        let patient = PatientDisplayModel(
            patientName: "DOE^JANE^MARIE",
            patientID: "PAT002",
            birthDate: birthDate,
            sex: .female,
            numberOfStudies: 5
        )
        
        XCTAssertEqual(patient.sex, .female)
        XCTAssertEqual(patient.numberOfStudies, 5)
        XCTAssertNotNil(patient.birthDate)
    }
    
    // MARK: - Formatted Name Tests
    
    func testFormattedNameLastFirst() {
        let patient = PatientDisplayModel(
            patientName: "SMITH^JOHN",
            patientID: "001"
        )
        
        XCTAssertEqual(patient.formattedName, "SMITH, JOHN")
    }
    
    func testFormattedNameWithMiddle() {
        let patient = PatientDisplayModel(
            patientName: "DOE^JANE^MARIE",
            patientID: "002"
        )
        
        XCTAssertEqual(patient.formattedName, "DOE, JANE MARIE")
    }
    
    func testFormattedNameLastOnly() {
        let patient = PatientDisplayModel(
            patientName: "JONES",
            patientID: "003"
        )
        
        XCTAssertEqual(patient.formattedName, "JONES")
    }
    
    func testFormattedNameEmpty() {
        let patient = PatientDisplayModel(
            patientName: "",
            patientID: "004"
        )
        
        XCTAssertEqual(patient.formattedName, "")
    }
    
    // MARK: - Age Calculation Tests
    
    func testAgeCalculation() {
        let yearsAgo = 30
        let birthDate = Calendar.current.date(byAdding: .year, value: -yearsAgo, to: Date())!
        
        let patient = PatientDisplayModel(
            patientName: "TEST^PATIENT",
            patientID: "001",
            birthDate: birthDate
        )
        
        XCTAssertEqual(patient.age, yearsAgo)
        XCTAssertEqual(patient.ageString, "\(yearsAgo) years")
    }
    
    func testAgeWithNoBirthDate() {
        let patient = PatientDisplayModel(
            patientName: "TEST",
            patientID: "001"
        )
        
        XCTAssertNil(patient.age)
        XCTAssertNil(patient.ageString)
    }
    
    // MARK: - Formatted Birth Date Tests
    
    func testFormattedBirthDate() {
        var components = DateComponents()
        components.year = 1990
        components.month = 6
        components.day = 15
        let date = Calendar.current.date(from: components)!
        
        let patient = PatientDisplayModel(
            patientName: "TEST",
            patientID: "001",
            birthDate: date
        )
        
        XCTAssertNotNil(patient.formattedBirthDate)
        // The exact format depends on locale, so just check it's not empty
        XCTAssertFalse(patient.formattedBirthDate!.isEmpty)
    }
    
    func testFormattedBirthDateNil() {
        let patient = PatientDisplayModel(
            patientName: "TEST",
            patientID: "001"
        )
        
        XCTAssertNil(patient.formattedBirthDate)
    }
    
    // MARK: - Sample Data Tests
    
    func testSampleList() {
        let samples = PatientDisplayModel.sampleList
        
        XCTAssertFalse(samples.isEmpty)
        XCTAssertEqual(samples.count, 3)
        
        // Check that all samples have required fields
        for patient in samples {
            XCTAssertFalse(patient.patientName.isEmpty)
            XCTAssertFalse(patient.patientID.isEmpty)
        }
    }
}

/// Tests for the StudyDisplayModel.
final class StudyDisplayModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testBasicInitialization() {
        let study = StudyDisplayModel(
            studyInstanceUID: "1.2.3.4.5",
            patientID: "PAT001"
        )
        
        XCTAssertEqual(study.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(study.patientID, "PAT001")
        XCTAssertTrue(study.studyDescription.isEmpty)
        XCTAssertTrue(study.modalitiesInStudy.isEmpty)
    }
    
    func testFullInitialization() {
        let study = StudyDisplayModel(
            studyInstanceUID: "1.2.3.4.5",
            patientID: "PAT001",
            studyDate: Date(),
            studyDescription: "CT CHEST",
            accessionNumber: "ACC001",
            modalitiesInStudy: ["CT", "MR"],
            numberOfSeries: 4,
            numberOfImages: 200
        )
        
        XCTAssertEqual(study.numberOfSeries, 4)
        XCTAssertEqual(study.numberOfImages, 200)
        XCTAssertEqual(study.modalitiesInStudy.count, 2)
    }
    
    // MARK: - Modalities String Tests
    
    func testModalitiesString() {
        let study = StudyDisplayModel(
            studyInstanceUID: "1.2.3",
            patientID: "001",
            modalitiesInStudy: ["CT", "MR", "US"]
        )
        
        XCTAssertEqual(study.modalitiesString, "CT, MR, US")
    }
    
    func testModalitiesStringEmpty() {
        let study = StudyDisplayModel(
            studyInstanceUID: "1.2.3",
            patientID: "001"
        )
        
        XCTAssertEqual(study.modalitiesString, "")
    }
    
    // MARK: - Formatted Date/Time Tests
    
    func testFormattedStudyDate() {
        let study = StudyDisplayModel(
            studyInstanceUID: "1.2.3",
            patientID: "001",
            studyDate: Date()
        )
        
        XCTAssertNotNil(study.formattedStudyDate)
    }
    
    func testFormattedDateTime() {
        let study = StudyDisplayModel(
            studyInstanceUID: "1.2.3",
            patientID: "001",
            studyDate: Date(),
            studyTime: Date()
        )
        
        XCTAssertNotNil(study.formattedDateTime)
    }
    
    // MARK: - Sample Data Tests
    
    func testSampleList() {
        let samples = StudyDisplayModel.sampleList
        
        XCTAssertFalse(samples.isEmpty)
        
        for study in samples {
            XCTAssertFalse(study.studyInstanceUID.isEmpty)
            XCTAssertFalse(study.patientID.isEmpty)
        }
    }
}

/// Tests for the SeriesDisplayModel.
final class SeriesDisplayModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testBasicInitialization() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3.4.5.1",
            studyInstanceUID: "1.2.3.4.5"
        )
        
        XCTAssertEqual(series.seriesInstanceUID, "1.2.3.4.5.1")
        XCTAssertEqual(series.studyInstanceUID, "1.2.3.4.5")
        XCTAssertNil(series.seriesNumber)
    }
    
    func testFullInitialization() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3.4.5.1",
            studyInstanceUID: "1.2.3.4.5",
            seriesNumber: 1,
            seriesDescription: "SCOUT",
            modality: "CT",
            bodyPartExamined: "CHEST",
            numberOfImages: 120
        )
        
        XCTAssertEqual(series.seriesNumber, 1)
        XCTAssertEqual(series.modality, "CT")
        XCTAssertEqual(series.numberOfImages, 120)
    }
    
    // MARK: - Display Title Tests
    
    func testDisplayTitleWithNumberAndDescription() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            seriesNumber: 2,
            seriesDescription: "AXIAL 5mm"
        )
        
        XCTAssertEqual(series.displayTitle, "Series 2: AXIAL 5mm")
    }
    
    func testDisplayTitleWithNumberOnly() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            seriesNumber: 3
        )
        
        XCTAssertEqual(series.displayTitle, "Series 3")
    }
    
    func testDisplayTitleWithDescriptionOnly() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            seriesDescription: "SCOUT"
        )
        
        XCTAssertEqual(series.displayTitle, "SCOUT")
    }
    
    func testDisplayTitleUntitled() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2"
        )
        
        XCTAssertEqual(series.displayTitle, "Untitled Series")
    }
    
    // MARK: - Display Subtitle Tests
    
    func testDisplaySubtitle() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "MR",
            bodyPartExamined: "BRAIN"
        )
        
        XCTAssertEqual(series.displaySubtitle, "MR - BRAIN")
    }
    
    func testDisplaySubtitleModalityOnly() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            modality: "CT"
        )
        
        XCTAssertEqual(series.displaySubtitle, "CT")
    }
    
    // MARK: - Image Count String Tests
    
    func testImageCountStringSingular() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            numberOfImages: 1
        )
        
        XCTAssertEqual(series.imageCountString, "1 image")
    }
    
    func testImageCountStringPlural() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2",
            numberOfImages: 50
        )
        
        XCTAssertEqual(series.imageCountString, "50 images")
    }
    
    func testImageCountStringNil() {
        let series = SeriesDisplayModel(
            seriesInstanceUID: "1.2.3",
            studyInstanceUID: "1.2"
        )
        
        XCTAssertNil(series.imageCountString)
    }
    
    // MARK: - Sample Data Tests
    
    func testSampleList() {
        let samples = SeriesDisplayModel.sampleList
        
        XCTAssertFalse(samples.isEmpty)
        
        for series in samples {
            XCTAssertFalse(series.seriesInstanceUID.isEmpty)
            XCTAssertFalse(series.studyInstanceUID.isEmpty)
        }
    }
}

/// Tests for ConnectionStatus.
final class ConnectionStatusTests: XCTestCase {
    
    func testSuccessStatus() {
        let status = ConnectionStatus.success(responseTimeMs: 150)
        
        XCTAssertTrue(status.success)
        XCTAssertEqual(status.responseTimeMs, 150)
        XCTAssertNil(status.errorMessage)
        XCTAssertNotNil(status.timestamp)
    }
    
    func testFailureStatus() {
        let status = ConnectionStatus.failure("Connection refused")
        
        XCTAssertFalse(status.success)
        XCTAssertNil(status.responseTimeMs)
        XCTAssertEqual(status.errorMessage, "Connection refused")
        XCTAssertNotNil(status.timestamp)
    }
}
