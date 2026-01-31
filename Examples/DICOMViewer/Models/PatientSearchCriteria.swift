// PatientSearchCriteria.swift
// DICOMViewer
//
// Patient search criteria model for PACS queries
//

import Foundation

/// Represents the search criteria for querying patients from a PACS server.
///
/// Supports wildcards (* and ?) in name and ID fields, and date range filtering.
public struct PatientSearchCriteria: Codable, Hashable, Sendable {
    /// Patient name filter (supports wildcards: SMITH*, *JOHN*, etc.)
    public var patientName: String
    
    /// Patient ID filter
    public var patientID: String
    
    /// Birth date range start (inclusive)
    public var birthDateFrom: Date?
    
    /// Birth date range end (inclusive)
    public var birthDateTo: Date?
    
    /// Patient sex filter
    public var sex: PatientSex?
    
    /// Accession number filter (for study-level queries)
    public var accessionNumber: String
    
    /// Modality filter (e.g., "CT", "MR", "US")
    public var modality: String
    
    /// Study date range start (inclusive)
    public var studyDateFrom: Date?
    
    /// Study date range end (inclusive)
    public var studyDateTo: Date?
    
    /// Creates a new patient search criteria.
    ///
    /// - Parameters:
    ///   - patientName: Patient name filter
    ///   - patientID: Patient ID filter
    ///   - birthDateFrom: Birth date range start
    ///   - birthDateTo: Birth date range end
    ///   - sex: Patient sex filter
    ///   - accessionNumber: Accession number filter
    ///   - modality: Modality filter
    ///   - studyDateFrom: Study date range start
    ///   - studyDateTo: Study date range end
    public init(
        patientName: String = "",
        patientID: String = "",
        birthDateFrom: Date? = nil,
        birthDateTo: Date? = nil,
        sex: PatientSex? = nil,
        accessionNumber: String = "",
        modality: String = "",
        studyDateFrom: Date? = nil,
        studyDateTo: Date? = nil
    ) {
        self.patientName = patientName
        self.patientID = patientID
        self.birthDateFrom = birthDateFrom
        self.birthDateTo = birthDateTo
        self.sex = sex
        self.accessionNumber = accessionNumber
        self.modality = modality
        self.studyDateFrom = studyDateFrom
        self.studyDateTo = studyDateTo
    }
    
    /// Whether all search fields are empty.
    public var isEmpty: Bool {
        patientName.isEmpty &&
        patientID.isEmpty &&
        birthDateFrom == nil &&
        birthDateTo == nil &&
        sex == nil &&
        accessionNumber.isEmpty &&
        modality.isEmpty &&
        studyDateFrom == nil &&
        studyDateTo == nil
    }
    
    /// Clears all search criteria.
    public mutating func clear() {
        self = PatientSearchCriteria()
    }
}

// MARK: - PatientSex

/// Patient sex enumeration matching DICOM values.
public enum PatientSex: String, Codable, CaseIterable, Hashable, Sendable {
    case male = "M"
    case female = "F"
    case other = "O"
    
    /// Display name for the sex value.
    public var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

// MARK: - Date Formatting

extension PatientSearchCriteria {
    /// Formats birth date range for DICOM query (YYYYMMDD-YYYYMMDD).
    public var birthDateRangeString: String? {
        formatDateRange(from: birthDateFrom, to: birthDateTo)
    }
    
    /// Formats study date range for DICOM query (YYYYMMDD-YYYYMMDD).
    public var studyDateRangeString: String? {
        formatDateRange(from: studyDateFrom, to: studyDateTo)
    }
    
    private func formatDateRange(from: Date?, to: Date?) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        
        switch (from, to) {
        case (let fromDate?, let toDate?):
            return "\(formatter.string(from: fromDate))-\(formatter.string(from: toDate))"
        case (let fromDate?, nil):
            return "\(formatter.string(from: fromDate))-"
        case (nil, let toDate?):
            return "-\(formatter.string(from: toDate))"
        case (nil, nil):
            return nil
        }
    }
}

// MARK: - Quick Filters

extension PatientSearchCriteria {
    /// Creates a criteria for today's studies.
    public static var today: PatientSearchCriteria {
        var criteria = PatientSearchCriteria()
        let now = Date()
        criteria.studyDateFrom = Calendar.current.startOfDay(for: now)
        criteria.studyDateTo = now
        return criteria
    }
    
    /// Creates a criteria for this week's studies.
    public static var thisWeek: PatientSearchCriteria {
        var criteria = PatientSearchCriteria()
        let now = Date()
        let calendar = Calendar.current
        if let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
            criteria.studyDateFrom = weekStart
            criteria.studyDateTo = now
        }
        return criteria
    }
    
    /// Creates a criteria for this month's studies.
    public static var thisMonth: PatientSearchCriteria {
        var criteria = PatientSearchCriteria()
        let now = Date()
        let calendar = Calendar.current
        if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) {
            criteria.studyDateFrom = monthStart
            criteria.studyDateTo = now
        }
        return criteria
    }
}
