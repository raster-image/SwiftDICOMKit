// PACSQueryService.swift
// DICOMViewer
//
// Service for querying PACS servers using C-FIND
//

import Foundation
import DICOMCore
import DICOMNetwork

/// Service for querying PACS servers for patient, study, and series information.
///
/// This service wraps the DICOMNetwork query functionality to provide
/// convenient methods for searching PACS data at different hierarchy levels.
public actor PACSQueryService {
    
    /// Shared instance for convenience.
    public static let shared = PACSQueryService()
    
    /// Creates a new PACS query service.
    public init() {}
    
    // MARK: - Patient Queries
    
    /// Searches for patients matching the given criteria.
    ///
    /// - Parameters:
    ///   - server: The PACS server to query.
    ///   - criteria: The search criteria to match.
    /// - Returns: Array of matching patient display models.
    public func findPatients(
        on server: PACSServer,
        matching criteria: PatientSearchCriteria
    ) async throws -> [PatientDisplayModel] {
        // Build query keys
        var queryKeys = QueryKeys(level: .patient)
            .requestPatientName()
            .requestPatientID()
            .requestPatientBirthDate()
            .requestPatientSex()
            .requestNumberOfPatientRelatedStudies()
        
        // Apply search criteria
        if !criteria.patientName.isEmpty {
            queryKeys = queryKeys.patientName(criteria.patientName)
        }
        
        if !criteria.patientID.isEmpty {
            queryKeys = queryKeys.patientID(criteria.patientID)
        }
        
        if let sex = criteria.sex {
            queryKeys = queryKeys.patientSex(sex.rawValue)
        }
        
        if let dateRange = criteria.birthDateRangeString {
            queryKeys = queryKeys.patientBirthDate(dateRange)
        }
        
        // Create query configuration
        let callingAETitle = try AETitle(server.callingAETitle)
        let calledAETitle = try AETitle(server.calledAETitle)
        let config = QueryConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: server.timeout
        )
        
        // Execute query
        let results = try await DICOMQueryService.find(
            host: server.host,
            port: server.port,
            configuration: config,
            queryKeys: queryKeys
        )
        
        // Convert to display models
        return results.map { convertToPatientDisplayModel($0.toPatientResult()) }
    }
    
    // MARK: - Study Queries
    
    /// Finds all studies for a specific patient.
    ///
    /// - Parameters:
    ///   - server: The PACS server to query.
    ///   - patientID: The patient ID to search for.
    ///   - dateRange: Optional study date range filter.
    ///   - modality: Optional modality filter.
    /// - Returns: Array of matching study display models.
    public func findStudies(
        on server: PACSServer,
        forPatientID patientID: String,
        dateRange: String? = nil,
        modality: String? = nil
    ) async throws -> [StudyDisplayModel] {
        // Use the convenience method which handles configuration internally
        var queryKeys = QueryKeys(level: .study)
            .patientID(patientID)
            .requestStudyInstanceUID()
            .requestStudyDate()
            .requestStudyTime()
            .requestStudyDescription()
            .requestAccessionNumber()
            .requestReferringPhysicianName()
            .requestModalitiesInStudy()
            .requestNumberOfStudyRelatedSeries()
            .requestNumberOfStudyRelatedInstances()
        
        if let dateRange = dateRange {
            queryKeys = queryKeys.studyDate(dateRange)
        }
        
        if let modality = modality, !modality.isEmpty {
            queryKeys = queryKeys.modalitiesInStudy(modality)
        }
        
        // Execute query using convenience method
        let results = try await DICOMQueryService.findStudies(
            host: server.host,
            port: server.port,
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            matching: queryKeys,
            timeout: server.timeout
        )
        
        // Convert to display models
        return results.map { convertToStudyDisplayModel($0, patientID: patientID) }
    }
    
    // MARK: - Series Queries
    
    /// Finds all series for a specific study.
    ///
    /// - Parameters:
    ///   - server: The PACS server to query.
    ///   - studyInstanceUID: The study instance UID to search for.
    ///   - modality: Optional modality filter.
    /// - Returns: Array of matching series display models.
    public func findSeries(
        on server: PACSServer,
        forStudyInstanceUID studyInstanceUID: String,
        modality: String? = nil
    ) async throws -> [SeriesDisplayModel] {
        // Build query keys
        var queryKeys = QueryKeys(level: .series)
            .requestSeriesInstanceUID()
            .requestSeriesNumber()
            .requestSeriesDescription()
            .requestModality()
            .requestBodyPartExamined()
            .requestSeriesDate()
            .requestSeriesTime()
            .requestNumberOfSeriesRelatedInstances()
        
        if let modality = modality, !modality.isEmpty {
            queryKeys = queryKeys.modality(modality)
        }
        
        // Execute query
        let results = try await DICOMQueryService.findSeries(
            host: server.host,
            port: server.port,
            callingAE: server.callingAETitle,
            calledAE: server.calledAETitle,
            forStudy: studyInstanceUID,
            matching: queryKeys,
            timeout: server.timeout
        )
        
        // Convert to display models
        return results.map { convertToSeriesDisplayModel($0, studyInstanceUID: studyInstanceUID) }
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToPatientDisplayModel(_ result: PatientResult) -> PatientDisplayModel {
        PatientDisplayModel(
            patientName: result.patientName ?? "",
            patientID: result.patientID ?? "",
            birthDate: parseDICOMDate(result.patientBirthDate),
            sex: result.patientSex.flatMap { PatientSex(rawValue: $0) },
            numberOfStudies: result.numberOfPatientRelatedStudies
        )
    }
    
    private func convertToStudyDisplayModel(_ result: StudyResult, patientID: String) -> StudyDisplayModel {
        StudyDisplayModel(
            studyInstanceUID: result.studyInstanceUID ?? "",
            patientID: patientID,
            studyDate: parseDICOMDate(result.studyDate),
            studyTime: parseDICOMTime(result.studyTime),
            studyDescription: result.studyDescription ?? "",
            accessionNumber: result.accessionNumber ?? "",
            referringPhysician: result.referringPhysicianName ?? "",
            modalitiesInStudy: result.modalities,
            numberOfSeries: result.numberOfStudyRelatedSeries,
            numberOfImages: result.numberOfStudyRelatedInstances
        )
    }
    
    private func convertToSeriesDisplayModel(_ result: SeriesResult, studyInstanceUID: String) -> SeriesDisplayModel {
        SeriesDisplayModel(
            seriesInstanceUID: result.seriesInstanceUID ?? "",
            studyInstanceUID: studyInstanceUID,
            seriesNumber: result.seriesNumber,
            seriesDescription: result.seriesDescription ?? "",
            modality: result.modality ?? "",
            bodyPartExamined: result.bodyPartExamined ?? "",
            numberOfImages: result.numberOfSeriesRelatedInstances,
            seriesDate: parseDICOMDate(result.seriesDate),
            seriesTime: parseDICOMTime(result.seriesTime)
        )
    }
    
    // MARK: - Date/Time Parsing
    
    private func parseDICOMDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateString)
    }
    
    private func parseDICOMTime(_ timeString: String?) -> Date? {
        guard let timeString = timeString, !timeString.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        // DICOM time can be HHMMSS.FFFFFF or just HHMMSS
        let cleanTime = timeString.prefix(6)
        formatter.dateFormat = "HHmmss"
        return formatter.date(from: String(cleanTime))
    }
}
