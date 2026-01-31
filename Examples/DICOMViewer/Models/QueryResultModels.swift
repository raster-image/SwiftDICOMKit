// QueryResultModels.swift
// DICOMViewer
//
// Display models for PACS query results
//

import Foundation

// MARK: - PatientDisplayModel

/// A display-friendly model representing a patient from PACS query results.
public struct PatientDisplayModel: Identifiable, Hashable, Sendable {
    public let id: String
    
    /// Patient's name in DICOM format (Last^First^Middle^Prefix^Suffix)
    public let patientName: String
    
    /// Patient's unique identifier
    public let patientID: String
    
    /// Patient's birth date
    public let birthDate: Date?
    
    /// Patient's sex
    public let sex: PatientSex?
    
    /// Number of studies associated with this patient
    public let numberOfStudies: Int?
    
    /// Creates a new patient display model.
    public init(
        id: String = UUID().uuidString,
        patientName: String,
        patientID: String,
        birthDate: Date? = nil,
        sex: PatientSex? = nil,
        numberOfStudies: Int? = nil
    ) {
        self.id = id
        self.patientName = patientName
        self.patientID = patientID
        self.birthDate = birthDate
        self.sex = sex
        self.numberOfStudies = numberOfStudies
    }
    
    /// Formatted patient name (Last, First Middle).
    public var formattedName: String {
        // DICOM format: Last^First^Middle^Prefix^Suffix
        let components = patientName.split(separator: "^").map(String.init)
        guard !components.isEmpty else { return patientName }
        
        let lastName = components[0]
        let firstName = components.count > 1 ? components[1] : ""
        let middleName = components.count > 2 ? components[2] : ""
        
        var result = lastName
        if !firstName.isEmpty {
            result += ", \(firstName)"
            if !middleName.isEmpty {
                result += " \(middleName)"
            }
        }
        return result
    }
    
    /// Calculated age based on birth date.
    public var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
    
    /// Formatted age string (e.g., "45 years").
    public var ageString: String? {
        guard let age = age else { return nil }
        return "\(age) years"
    }
    
    /// Formatted birth date string.
    public var formattedBirthDate: String? {
        guard let birthDate = birthDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: birthDate)
    }
}

// MARK: - StudyDisplayModel

/// A display-friendly model representing a study from PACS query results.
public struct StudyDisplayModel: Identifiable, Hashable, Sendable {
    public let id: String
    
    /// Study Instance UID (unique identifier)
    public let studyInstanceUID: String
    
    /// Patient ID this study belongs to
    public let patientID: String
    
    /// Study date
    public let studyDate: Date?
    
    /// Study time
    public let studyTime: Date?
    
    /// Study description
    public let studyDescription: String
    
    /// Accession number
    public let accessionNumber: String
    
    /// Referring physician's name
    public let referringPhysician: String
    
    /// Modalities present in the study (e.g., "CT\\MR")
    public let modalitiesInStudy: [String]
    
    /// Number of series in this study
    public let numberOfSeries: Int?
    
    /// Total number of images in this study
    public let numberOfImages: Int?
    
    /// Creates a new study display model.
    public init(
        id: String = UUID().uuidString,
        studyInstanceUID: String,
        patientID: String,
        studyDate: Date? = nil,
        studyTime: Date? = nil,
        studyDescription: String = "",
        accessionNumber: String = "",
        referringPhysician: String = "",
        modalitiesInStudy: [String] = [],
        numberOfSeries: Int? = nil,
        numberOfImages: Int? = nil
    ) {
        self.id = id
        self.studyInstanceUID = studyInstanceUID
        self.patientID = patientID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.accessionNumber = accessionNumber
        self.referringPhysician = referringPhysician
        self.modalitiesInStudy = modalitiesInStudy
        self.numberOfSeries = numberOfSeries
        self.numberOfImages = numberOfImages
    }
    
    /// Formatted study date string.
    public var formattedStudyDate: String? {
        guard let studyDate = studyDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: studyDate)
    }
    
    /// Formatted study time string.
    public var formattedStudyTime: String? {
        guard let studyTime = studyTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: studyTime)
    }
    
    /// Combined date and time string.
    public var formattedDateTime: String? {
        let dateStr = formattedStudyDate ?? ""
        let timeStr = formattedStudyTime ?? ""
        if dateStr.isEmpty && timeStr.isEmpty { return nil }
        if timeStr.isEmpty { return dateStr }
        if dateStr.isEmpty { return timeStr }
        return "\(dateStr) at \(timeStr)"
    }
    
    /// Modalities as a joined string (e.g., "CT, MR").
    public var modalitiesString: String {
        modalitiesInStudy.joined(separator: ", ")
    }
}

// MARK: - SeriesDisplayModel

/// A display-friendly model representing a series from PACS query results.
public struct SeriesDisplayModel: Identifiable, Hashable, Sendable {
    public let id: String
    
    /// Series Instance UID (unique identifier)
    public let seriesInstanceUID: String
    
    /// Study Instance UID this series belongs to
    public let studyInstanceUID: String
    
    /// Series number within the study
    public let seriesNumber: Int?
    
    /// Series description
    public let seriesDescription: String
    
    /// Modality (e.g., "CT", "MR", "US")
    public let modality: String
    
    /// Body part examined
    public let bodyPartExamined: String
    
    /// Number of images in this series
    public let numberOfImages: Int?
    
    /// Series date
    public let seriesDate: Date?
    
    /// Series time
    public let seriesTime: Date?
    
    /// Creates a new series display model.
    public init(
        id: String = UUID().uuidString,
        seriesInstanceUID: String,
        studyInstanceUID: String,
        seriesNumber: Int? = nil,
        seriesDescription: String = "",
        modality: String = "",
        bodyPartExamined: String = "",
        numberOfImages: Int? = nil,
        seriesDate: Date? = nil,
        seriesTime: Date? = nil
    ) {
        self.id = id
        self.seriesInstanceUID = seriesInstanceUID
        self.studyInstanceUID = studyInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.bodyPartExamined = bodyPartExamined
        self.numberOfImages = numberOfImages
        self.seriesDate = seriesDate
        self.seriesTime = seriesTime
    }
    
    /// Display title combining series number and description.
    public var displayTitle: String {
        var parts: [String] = []
        if let number = seriesNumber {
            parts.append("Series \(number)")
        }
        if !seriesDescription.isEmpty {
            parts.append(seriesDescription)
        }
        return parts.isEmpty ? "Untitled Series" : parts.joined(separator: ": ")
    }
    
    /// Subtitle with modality and body part.
    public var displaySubtitle: String {
        var parts: [String] = []
        if !modality.isEmpty {
            parts.append(modality)
        }
        if !bodyPartExamined.isEmpty {
            parts.append(bodyPartExamined)
        }
        return parts.joined(separator: " - ")
    }
    
    /// Formatted image count string.
    public var imageCountString: String? {
        guard let count = numberOfImages else { return nil }
        return count == 1 ? "1 image" : "\(count) images"
    }
}

// MARK: - ConnectionStatus

/// Represents the status of a PACS connection test.
public struct ConnectionStatus: Sendable {
    /// Whether the connection was successful
    public let success: Bool
    
    /// Response time in milliseconds
    public let responseTimeMs: Double?
    
    /// Error message if connection failed
    public let errorMessage: String?
    
    /// Timestamp of the test
    public let timestamp: Date
    
    /// Creates a successful connection status.
    public static func success(responseTimeMs: Double) -> ConnectionStatus {
        ConnectionStatus(
            success: true,
            responseTimeMs: responseTimeMs,
            errorMessage: nil,
            timestamp: Date()
        )
    }
    
    /// Creates a failed connection status.
    public static func failure(_ message: String) -> ConnectionStatus {
        ConnectionStatus(
            success: false,
            responseTimeMs: nil,
            errorMessage: message,
            timestamp: Date()
        )
    }
}

// MARK: - Sample Data

extension PatientDisplayModel {
    /// Sample patients for preview purposes.
    public static var sampleList: [PatientDisplayModel] {
        [
            PatientDisplayModel(
                patientName: "SMITH^JOHN^MICHAEL",
                patientID: "PAT001",
                birthDate: Calendar.current.date(byAdding: .year, value: -45, to: Date()),
                sex: .male,
                numberOfStudies: 3
            ),
            PatientDisplayModel(
                patientName: "JOHNSON^SARAH^ANN",
                patientID: "PAT002",
                birthDate: Calendar.current.date(byAdding: .year, value: -32, to: Date()),
                sex: .female,
                numberOfStudies: 1
            ),
            PatientDisplayModel(
                patientName: "WILLIAMS^ROBERT",
                patientID: "PAT003",
                birthDate: Calendar.current.date(byAdding: .year, value: -67, to: Date()),
                sex: .male,
                numberOfStudies: 5
            )
        ]
    }
}

extension StudyDisplayModel {
    /// Sample studies for preview purposes.
    public static var sampleList: [StudyDisplayModel] {
        [
            StudyDisplayModel(
                studyInstanceUID: "1.2.3.4.5.6.7.8.9.1",
                patientID: "PAT001",
                studyDate: Date(),
                studyDescription: "CT CHEST W/CONTRAST",
                accessionNumber: "ACC001",
                referringPhysician: "Dr. Smith",
                modalitiesInStudy: ["CT"],
                numberOfSeries: 4,
                numberOfImages: 245
            ),
            StudyDisplayModel(
                studyInstanceUID: "1.2.3.4.5.6.7.8.9.2",
                patientID: "PAT001",
                studyDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
                studyDescription: "MR BRAIN W/O CONTRAST",
                accessionNumber: "ACC002",
                referringPhysician: "Dr. Johnson",
                modalitiesInStudy: ["MR"],
                numberOfSeries: 6,
                numberOfImages: 180
            )
        ]
    }
}

extension SeriesDisplayModel {
    /// Sample series for preview purposes.
    public static var sampleList: [SeriesDisplayModel] {
        [
            SeriesDisplayModel(
                seriesInstanceUID: "1.2.3.4.5.6.7.8.9.1.1",
                studyInstanceUID: "1.2.3.4.5.6.7.8.9.1",
                seriesNumber: 1,
                seriesDescription: "SCOUT",
                modality: "CT",
                bodyPartExamined: "CHEST",
                numberOfImages: 2
            ),
            SeriesDisplayModel(
                seriesInstanceUID: "1.2.3.4.5.6.7.8.9.1.2",
                studyInstanceUID: "1.2.3.4.5.6.7.8.9.1",
                seriesNumber: 2,
                seriesDescription: "AXIAL 5mm",
                modality: "CT",
                bodyPartExamined: "CHEST",
                numberOfImages: 120
            ),
            SeriesDisplayModel(
                seriesInstanceUID: "1.2.3.4.5.6.7.8.9.1.3",
                studyInstanceUID: "1.2.3.4.5.6.7.8.9.1",
                seriesNumber: 3,
                seriesDescription: "CORONAL MPR",
                modality: "CT",
                bodyPartExamined: "CHEST",
                numberOfImages: 60
            )
        ]
    }
}
