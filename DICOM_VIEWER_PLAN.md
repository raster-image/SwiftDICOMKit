# DICOM Viewer Implementation Plan

A comprehensive phase-by-phase plan for building a DICOM Viewer application that explores patients from a PACS (Picture Archiving and Communication System) and loads images using DICOMKit.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Phase 1: Project Setup and PACS Configuration](#phase-1-project-setup-and-pacs-configuration)
- [Phase 2: Patient Browsing and Study Discovery](#phase-2-patient-browsing-and-study-discovery)
- [Phase 3: Image Retrieval from PACS](#phase-3-image-retrieval-from-pacs)
- [Phase 4: Image Display and Viewer Implementation](#phase-4-image-display-and-viewer-implementation)
- [Phase 5: Advanced Features](#phase-5-advanced-features)
- [Architecture Overview](#architecture-overview)
- [Security Considerations](#security-considerations)

---

## Overview

This plan outlines how to build a DICOM Viewer application using DICOMKit that:

1. Connects to a PACS server
2. Queries and browses patients, studies, and series
3. Retrieves DICOM images from the PACS
4. Displays medical images with proper rendering

### DICOMKit Features Used

- **C-ECHO** - Verify PACS connectivity
- **C-FIND** - Query patients, studies, series, and instances
- **C-MOVE / C-GET** - Retrieve DICOM images
- **Storage SCP** - Receive pushed images (for C-MOVE)
- **Pixel Data Rendering** - Display images as CGImage
- **Window/Level** - Apply VOI LUT transformations

---

## Prerequisites

### Development Environment

- **Xcode 16+** with Swift 6.2
- **macOS 14.0+** / **iOS 17.0+** / **visionOS 1.0+**
- **DICOMKit v0.7.7+**

### PACS Requirements

- A DICOM-compliant PACS server (e.g., Orthanc, dcm4chee, Horos)
- Network access to the PACS server
- Configured AE Titles for your application

### Add DICOMKit Dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/raster-image/DICOMKit.git", from: "0.7.7")
]
```

---

## Phase 1: Project Setup and PACS Configuration

### 1.1 Define PACS Configuration

Create a configuration structure to store PACS connection details:

```swift
import DICOMKit

/// Configuration for connecting to a PACS server
struct PACSConfiguration {
    /// PACS server hostname or IP address
    let host: String
    
    /// PACS server port (default DICOM port is 104, often 11112)
    let port: UInt16
    
    /// Your application's AE Title (Application Entity)
    let callingAETitle: String
    
    /// The PACS server's AE Title
    let calledAETitle: String
    
    /// Connection timeout in seconds
    let timeout: TimeInterval
    
    /// Whether to use TLS encryption
    let tlsEnabled: Bool
    
    /// Optional TLS configuration
    let tlsConfiguration: TLSConfiguration?
    
    /// Default configuration for local development
    static let localDevelopment = PACSConfiguration(
        host: "localhost",
        port: 11112,
        callingAETitle: "DICOM_VIEWER",
        calledAETitle: "ORTHANC",
        timeout: 30,
        tlsEnabled: false,
        tlsConfiguration: nil
    )
    
    init(
        host: String,
        port: UInt16 = 11112,
        callingAETitle: String,
        calledAETitle: String,
        timeout: TimeInterval = 60,
        tlsEnabled: Bool = false,
        tlsConfiguration: TLSConfiguration? = nil
    ) {
        self.host = host
        self.port = port
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.tlsEnabled = tlsEnabled
        self.tlsConfiguration = tlsConfiguration
    }
}
```

### 1.2 Create PACS Connection Manager

Implement a connection manager to handle PACS operations:

```swift
import DICOMKit

/// Manages connections and operations with a PACS server
@MainActor
class PACSConnectionManager: ObservableObject {
    
    @Published var isConnected: Bool = false
    @Published var connectionError: Error?
    
    private let configuration: PACSConfiguration
    private var client: DICOMClient?
    
    init(configuration: PACSConfiguration) {
        self.configuration = configuration
    }
    
    /// Creates a DICOMClient with the current configuration
    func createClient() throws -> DICOMClient {
        let clientConfig = try DICOMClientConfiguration(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle,
            calledAE: configuration.calledAETitle,
            timeout: configuration.timeout,
            tlsConfiguration: configuration.tlsConfiguration
        )
        return DICOMClient(configuration: clientConfig)
    }
}
```

### 1.3 Verify PACS Connectivity

Implement C-ECHO to test the connection:

```swift
extension PACSConnectionManager {
    
    /// Tests connectivity to the PACS server using C-ECHO
    func verifyConnection() async throws -> Bool {
        do {
            // Use the static DICOMVerificationService for simple echo test
            let success = try await DICOMVerificationService.echo(
                host: configuration.host,
                port: configuration.port,
                callingAE: configuration.callingAETitle,
                calledAE: configuration.calledAETitle,
                timeout: configuration.timeout
            )
            
            await MainActor.run {
                self.isConnected = success
                self.connectionError = nil
            }
            
            return success
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.connectionError = error
            }
            throw error
        }
    }
}
```

### 1.4 Phase 1 Deliverables Checklist

- [ ] Project created with DICOMKit dependency
- [ ] PACSConfiguration struct defined
- [ ] PACSConnectionManager class implemented
- [ ] C-ECHO connectivity test working
- [ ] Settings UI for configuring PACS connection
- [ ] Error handling for connection failures

---

## Phase 2: Patient Browsing and Study Discovery

### 2.1 Query for Patients

Use C-FIND at the PATIENT level to search for patients:

```swift
extension PACSConnectionManager {
    
    /// Searches for patients matching the specified criteria
    /// - Parameters:
    ///   - patientName: Patient name pattern (supports wildcards: *, ?)
    ///   - patientID: Patient ID pattern
    /// - Returns: Array of PatientResult objects
    func findPatients(
        patientName: String? = nil,
        patientID: String? = nil
    ) async throws -> [PatientResult] {
        
        // Build query keys for patient-level search
        var queryKeys = QueryKeys(level: .patient)
        
        // Add search criteria
        if let name = patientName, !name.isEmpty {
            queryKeys = queryKeys.patientName(name)
        }
        
        if let id = patientID, !id.isEmpty {
            queryKeys = queryKeys.patientID(id)
        }
        
        // Request additional return fields
        queryKeys = queryKeys
            .patientBirthDate("")
            .patientSex("")
        
        // Execute the query using Patient Root information model
        let results = try await DICOMQueryService.find(
            host: configuration.host,
            port: configuration.port,
            configuration: QueryConfiguration(
                callingAETitle: try AETitle(configuration.callingAETitle),
                calledAETitle: try AETitle(configuration.calledAETitle),
                timeout: configuration.timeout,
                informationModel: .patientRoot
            ),
            queryKeys: queryKeys
        )
        
        // Convert to PatientResult objects
        return results.map { $0.toPatientResult() }
    }
}
```

### 2.2 Query for Studies

Search for studies belonging to a patient:

```swift
extension PACSConnectionManager {
    
    /// Finds all studies for a specific patient
    /// - Parameter patientID: The patient's ID
    /// - Returns: Array of StudyResult objects
    func findStudies(forPatientID patientID: String) async throws -> [StudyResult] {
        
        var queryKeys = QueryKeys.defaultStudyKeys()
            .patientID(patientID)
        
        return try await DICOMQueryService.findStudies(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle,
            calledAE: configuration.calledAETitle,
            matching: queryKeys,
            timeout: configuration.timeout
        )
    }
    
    /// Searches for studies matching the specified criteria
    /// - Parameters:
    ///   - patientName: Patient name pattern (wildcards supported)
    ///   - studyDate: Study date or date range (e.g., "20240101-20241231")
    ///   - modality: Modality filter (e.g., "CT", "MR", "CR")
    ///   - accessionNumber: Accession number
    /// - Returns: Array of StudyResult objects
    func searchStudies(
        patientName: String? = nil,
        studyDate: String? = nil,
        modality: String? = nil,
        accessionNumber: String? = nil
    ) async throws -> [StudyResult] {
        
        var queryKeys = QueryKeys.defaultStudyKeys()
        
        if let name = patientName, !name.isEmpty {
            queryKeys = queryKeys.patientName(name)
        }
        
        if let date = studyDate, !date.isEmpty {
            queryKeys = queryKeys.studyDate(date)
        }
        
        if let mod = modality, !mod.isEmpty {
            queryKeys = queryKeys.modalitiesInStudy(mod)
        }
        
        if let accession = accessionNumber, !accession.isEmpty {
            queryKeys = queryKeys.accessionNumber(accession)
        }
        
        return try await DICOMQueryService.findStudies(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle,
            calledAE: configuration.calledAETitle,
            matching: queryKeys,
            timeout: configuration.timeout
        )
    }
}
```

### 2.3 Query for Series

Find series within a study:

```swift
extension PACSConnectionManager {
    
    /// Finds all series within a study
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - modality: Optional modality filter
    /// - Returns: Array of SeriesResult objects
    func findSeries(
        forStudy studyInstanceUID: String,
        modality: String? = nil
    ) async throws -> [SeriesResult] {
        
        var queryKeys: QueryKeys? = nil
        
        if let mod = modality, !mod.isEmpty {
            queryKeys = QueryKeys.defaultSeriesKeys().modality(mod)
        }
        
        return try await DICOMQueryService.findSeries(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle,
            calledAE: configuration.calledAETitle,
            forStudy: studyInstanceUID,
            matching: queryKeys,
            timeout: configuration.timeout
        )
    }
}
```

### 2.4 Query for Instances (Images)

Find individual images within a series:

```swift
extension PACSConnectionManager {
    
    /// Finds all instances (images) within a series
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    /// - Returns: Array of InstanceResult objects
    func findInstances(
        forStudy studyInstanceUID: String,
        forSeries seriesInstanceUID: String
    ) async throws -> [InstanceResult] {
        
        return try await DICOMQueryService.findInstances(
            host: configuration.host,
            port: configuration.port,
            callingAE: configuration.callingAETitle,
            calledAE: configuration.calledAETitle,
            forStudy: studyInstanceUID,
            forSeries: seriesInstanceUID,
            timeout: configuration.timeout
        )
    }
}
```

### 2.5 Create Data Models for UI

Define view models for displaying query results:

```swift
import SwiftUI

/// View model for displaying a patient in the UI
struct PatientViewModel: Identifiable {
    let id: String  // Patient ID
    let name: String
    let birthDate: String?
    let sex: String?
    
    init(from result: PatientResult) {
        self.id = result.patientID ?? UUID().uuidString
        self.name = result.patientName ?? "Unknown"
        self.birthDate = result.patientBirthDate
        self.sex = result.patientSex
    }
}

/// View model for displaying a study
struct StudyViewModel: Identifiable {
    let id: String  // Study Instance UID
    let patientName: String
    let patientID: String?
    let studyDate: String?
    let studyDescription: String?
    let modalities: String?
    let numberOfSeries: Int?
    let numberOfInstances: Int?
    
    init(from result: StudyResult) {
        self.id = result.studyInstanceUID ?? UUID().uuidString
        self.patientName = result.patientName ?? "Unknown"
        self.patientID = result.patientID
        self.studyDate = result.studyDate
        self.studyDescription = result.studyDescription
        self.modalities = result.modalitiesInStudy
        self.numberOfSeries = result.numberOfStudyRelatedSeries
        self.numberOfInstances = result.numberOfStudyRelatedInstances
    }
}

/// View model for displaying a series
struct SeriesViewModel: Identifiable {
    let id: String  // Series Instance UID
    let seriesNumber: Int?
    let modality: String?
    let seriesDescription: String?
    let numberOfInstances: Int?
    
    init(from result: SeriesResult) {
        self.id = result.seriesInstanceUID ?? UUID().uuidString
        self.seriesNumber = result.seriesNumber
        self.modality = result.modality
        self.seriesDescription = result.seriesDescription
        self.numberOfInstances = result.numberOfSeriesRelatedInstances
    }
}
```

### 2.6 Phase 2 Deliverables Checklist

- [ ] Patient search functionality (C-FIND at PATIENT level)
- [ ] Study search with multiple criteria
- [ ] Series listing for selected study
- [ ] Instance listing for selected series
- [ ] Patient list UI view
- [ ] Study list UI view with details
- [ ] Series list UI view with thumbnails (optional)
- [ ] Search filters UI (name, date range, modality)
- [ ] Loading states and error handling

---

## Phase 3: Image Retrieval from PACS

### 3.1 Choose Retrieval Method

DICOMKit supports two retrieval methods:

| Method | Description | Pros | Cons |
|--------|-------------|------|------|
| **C-GET** | Direct download to your application | Simpler setup, no SCP needed | Not all PACS support it |
| **C-MOVE** | PACS pushes images to your SCP | Widely supported | Requires running Storage SCP |

### 3.2 Retrieve Images Using C-GET

```swift
extension PACSConnectionManager {
    
    /// Retrieves a series using C-GET (direct download)
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    /// - Returns: AsyncStream of retrieved DICOM files
    func retrieveSeriesWithCGET(
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) -> AsyncThrowingStream<DICOMFile, Error> {
        
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let client = try createClient()
                    
                    // Retrieve using C-GET
                    for try await file in try await client.get(
                        studyInstanceUID: studyInstanceUID,
                        seriesInstanceUID: seriesInstanceUID
                    ) {
                        continuation.yield(file)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Retrieves a single instance using C-GET
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - sopInstanceUID: The SOP Instance UID
    /// - Returns: The retrieved DICOM file
    func retrieveInstance(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String
    ) async throws -> DICOMFile {
        
        let client = try createClient()
        
        // Retrieve the specific instance
        var retrievedFile: DICOMFile?
        
        for try await file in try await client.get(
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            sopInstanceUID: sopInstanceUID
        ) {
            retrievedFile = file
            break  // We only expect one file
        }
        
        guard let file = retrievedFile else {
            throw DICOMNetworkError.retrieveFailed(
                DIMSEStatus(code: 0xC000),
                "No file received for instance \(sopInstanceUID)"
            )
        }
        
        return file
    }
}
```

### 3.3 Retrieve Images Using C-MOVE with Storage SCP

For C-MOVE, you need to run a Storage SCP to receive images:

```swift
import DICOMKit

/// Manages the Storage SCP server for receiving C-MOVE results
class StorageSCPManager {
    
    private var storageSCP: DICOMStorageSCP?
    
    /// Local AE Title for the Storage SCP
    let aeTitle: String
    
    /// Port to listen on
    let port: UInt16
    
    /// Directory to store received files
    let storageDirectory: URL
    
    init(
        aeTitle: String = "DICOM_VIEWER_SCP",
        port: UInt16 = 11113,
        storageDirectory: URL? = nil
    ) {
        self.aeTitle = aeTitle
        self.port = port
        self.storageDirectory = storageDirectory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DICOMReceived")
    }
    
    /// Starts the Storage SCP server
    func start() async throws {
        // Ensure storage directory exists
        try FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
        
        // Create the Storage SCP
        let config = StorageSCPConfiguration(
            aeTitle: try AETitle(aeTitle),
            port: port,
            maxPDUSize: 65536,
            storageDirectory: storageDirectory
        )
        
        storageSCP = try DICOMStorageSCP(configuration: config)
        
        // Start listening
        try await storageSCP?.start()
        
        print("Storage SCP started on port \(port)")
    }
    
    /// Stops the Storage SCP server
    func stop() async {
        await storageSCP?.stop()
        storageSCP = nil
        print("Storage SCP stopped")
    }
    
    /// Returns an AsyncStream of received DICOM files
    func receivedFiles() async throws -> AsyncStream<DICOMStorageEvent> {
        guard let scp = storageSCP else {
            throw DICOMNetworkError.notConnected
        }
        return scp.events
    }
}

extension PACSConnectionManager {
    
    /// Retrieves a series using C-MOVE (requires Storage SCP)
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID
    ///   - seriesInstanceUID: The Series Instance UID
    ///   - destinationAE: The AE Title of the destination (your Storage SCP)
    /// - Returns: RetrieveResult with status information
    func retrieveSeriesWithCMOVE(
        studyInstanceUID: String,
        seriesInstanceUID: String,
        destinationAE: String
    ) async throws -> RetrieveResult {
        
        let client = try createClient()
        
        // Execute C-MOVE
        return try await client.move(
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            destinationAE: destinationAE
        )
    }
}
```

### 3.4 Implement Image Cache

Cache retrieved DICOM files for performance:

```swift
import Foundation

/// Caches retrieved DICOM files in memory and on disk
actor DICOMImageCache {
    
    /// In-memory cache for recently accessed files
    private var memoryCache: [String: DICOMFile] = [:]
    
    /// Maximum number of files to keep in memory
    private let maxMemoryCacheSize: Int
    
    /// Directory for disk cache
    private let diskCacheDirectory: URL
    
    init(
        maxMemoryCacheSize: Int = 100,
        diskCacheDirectory: URL? = nil
    ) {
        self.maxMemoryCacheSize = maxMemoryCacheSize
        self.diskCacheDirectory = diskCacheDirectory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DICOMCache")
        
        // Create cache directory
        try? FileManager.default.createDirectory(
            at: self.diskCacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    /// Stores a DICOM file in the cache
    /// Note: Uses simple FIFO eviction. For production, consider LRU with OrderedDictionary.
    func store(_ file: DICOMFile, forKey key: String) async throws {
        // Add to memory cache
        memoryCache[key] = file
        
        // Trim memory cache if needed (simple eviction - consider LRU for production)
        while memoryCache.count > maxMemoryCacheSize {
            if let firstKey = memoryCache.keys.first {
                memoryCache.removeValue(forKey: firstKey)
            } else {
                break
            }
        }
        
        // Write to disk cache
        let fileURL = diskCacheDirectory.appendingPathComponent("\(key).dcm")
        let data = try file.write()
        try data.write(to: fileURL)
    }
    
    /// Retrieves a DICOM file from the cache
    func retrieve(forKey key: String) async -> DICOMFile? {
        // Check memory cache first
        if let file = memoryCache[key] {
            return file
        }
        
        // Check disk cache
        let fileURL = diskCacheDirectory.appendingPathComponent("\(key).dcm")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Load from disk
        if let data = try? Data(contentsOf: fileURL),
           let file = try? DICOMFile.read(from: data) {
            // Add to memory cache
            memoryCache[key] = file
            return file
        }
        
        return nil
    }
    
    /// Clears the cache
    func clear() async {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(
            at: diskCacheDirectory,
            withIntermediateDirectories: true
        )
    }
}
```

### 3.5 Phase 3 Deliverables Checklist

- [ ] C-GET retrieval implementation
- [ ] C-MOVE retrieval implementation (optional)
- [ ] Storage SCP for receiving C-MOVE results (optional)
- [ ] Image cache for performance
- [ ] Download progress indication
- [ ] Background downloading support
- [ ] Error handling for retrieval failures
- [ ] Retry logic for transient failures

---

## Phase 4: Image Display and Viewer Implementation

### 4.1 Extract and Render Pixel Data

```swift
import DICOMKit
import CoreGraphics

/// Service for rendering DICOM images
struct DICOMImageRenderingService {
    
    /// Renders a DICOM file to a CGImage
    /// - Parameters:
    ///   - dicomFile: The DICOM file to render
    ///   - frameIndex: Frame index for multi-frame images (default: 0)
    ///   - windowSettings: Optional window/level settings
    /// - Returns: Rendered CGImage or nil if rendering fails
    static func renderImage(
        from dicomFile: DICOMFile,
        frameIndex: Int = 0,
        windowSettings: WindowSettings? = nil
    ) -> CGImage? {
        
        // Extract pixel data from the DICOM file
        guard let pixelData = dicomFile.pixelData() else {
            print("Failed to extract pixel data")
            return nil
        }
        
        // Create the renderer
        let renderer = PixelDataRenderer(
            pixelData: pixelData,
            paletteColorLUT: dicomFile.paletteColorLUT()
        )
        
        // Render with or without custom window settings
        if let window = windowSettings {
            return renderer.renderMonochromeFrame(frameIndex, window: window)
        } else {
            return renderer.renderFrame(frameIndex)
        }
    }
    
    /// Extracts window/level settings from a DICOM file
    static func extractWindowSettings(from dicomFile: DICOMFile) -> WindowSettings? {
        let dataSet = dicomFile.dataSet
        
        // Try to get stored window settings
        if let center = dataSet.floatArray(for: .windowCenter)?.first,
           let width = dataSet.floatArray(for: .windowWidth)?.first {
            return WindowSettings(center: Double(center), width: Double(width))
        }
        
        return nil
    }
    
    /// Gets the number of frames in a DICOM file
    static func frameCount(for dicomFile: DICOMFile) -> Int {
        return dicomFile.dataSet.integer(for: .numberOfFrames) ?? 1
    }
}
```

### 4.2 Create SwiftUI Image View

```swift
import SwiftUI
import DICOMKit

/// SwiftUI view for displaying a DICOM image
struct DICOMImageView: View {
    
    let dicomFile: DICOMFile
    
    @State private var currentFrame: Int = 0
    @State private var windowCenter: Double = 0
    @State private var windowWidth: Double = 1
    @State private var isInitialized: Bool = false
    
    /// Total number of frames in the image
    private var frameCount: Int {
        DICOMImageRenderingService.frameCount(for: dicomFile)
    }
    
    /// Whether this is a multi-frame image
    private var isMultiFrame: Bool {
        frameCount > 1
    }
    
    var body: some View {
        VStack {
            // Image display
            if let cgImage = renderCurrentFrame() {
                #if os(iOS) || os(visionOS)
                Image(uiImage: UIImage(cgImage: cgImage))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .gesture(windowLevelGesture)
                #elseif os(macOS)
                Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                ContentUnavailableView(
                    "Unable to Display",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Could not render the DICOM image")
                )
            }
            
            // Multi-frame controls
            if isMultiFrame {
                HStack {
                    Button(action: previousFrame) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentFrame == 0)
                    
                    Text("Frame \(currentFrame + 1) of \(frameCount)")
                        .monospacedDigit()
                    
                    Button(action: nextFrame) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentFrame >= frameCount - 1)
                }
                .padding()
            }
            
            // Window/Level info
            Text("W: \(Int(windowWidth)) L: \(Int(windowCenter))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            initializeWindowSettings()
        }
    }
    
    // MARK: - Private Methods
    
    private func renderCurrentFrame() -> CGImage? {
        let window = WindowSettings(center: windowCenter, width: windowWidth)
        return DICOMImageRenderingService.renderImage(
            from: dicomFile,
            frameIndex: currentFrame,
            windowSettings: window
        )
    }
    
    private func initializeWindowSettings() {
        guard !isInitialized else { return }
        
        if let stored = DICOMImageRenderingService.extractWindowSettings(from: dicomFile) {
            windowCenter = stored.center
            windowWidth = stored.width
        } else if let pixelData = dicomFile.pixelData(),
                  let range = pixelData.pixelRange(forFrame: 0) {
            // Calculate from pixel data
            windowCenter = Double(range.min + range.max) / 2.0
            windowWidth = Double(range.max - range.min)
        }
        
        isInitialized = true
    }
    
    private func previousFrame() {
        if currentFrame > 0 {
            currentFrame -= 1
        }
    }
    
    private func nextFrame() {
        if currentFrame < frameCount - 1 {
            currentFrame += 1
        }
    }
    
    /// Gesture for adjusting window/level
    private var windowLevelGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Horizontal = window width, Vertical = window center
                windowWidth = max(1, windowWidth + value.translation.width)
                windowCenter = windowCenter - value.translation.height
            }
    }
}
```

### 4.3 Create Series Viewer

```swift
import SwiftUI
import DICOMKit

/// View for browsing through a series of DICOM images
struct SeriesViewer: View {
    
    @StateObject private var viewModel: SeriesViewerViewModel
    
    init(
        connectionManager: PACSConnectionManager,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        _viewModel = StateObject(wrappedValue: SeriesViewerViewModel(
            connectionManager: connectionManager,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID
        ))
    }
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading series...")
                
            case .loaded:
                if let currentFile = viewModel.currentFile {
                    VStack {
                        DICOMImageView(dicomFile: currentFile)
                        
                        // Image navigation
                        HStack {
                            Button(action: viewModel.previousImage) {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(!viewModel.canGoBack)
                            
                            Text("\(viewModel.currentIndex + 1) / \(viewModel.totalImages)")
                                .monospacedDigit()
                            
                            Button(action: viewModel.nextImage) {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(!viewModel.canGoForward)
                        }
                        .padding()
                        
                        // Slider for quick navigation
                        if viewModel.totalImages > 1 {
                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.currentIndex) },
                                    set: { viewModel.goToImage(Int($0)) }
                                ),
                                in: 0...Double(viewModel.totalImages - 1),
                                step: 1
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                
            case .error(let error):
                ContentUnavailableView(
                    "Error Loading Series",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
        .task {
            await viewModel.loadSeries()
        }
    }
}

/// View model for the series viewer
@MainActor
class SeriesViewerViewModel: ObservableObject {
    
    enum State {
        case loading
        case loaded
        case error(Error)
    }
    
    @Published var state: State = .loading
    @Published var currentIndex: Int = 0
    
    private let connectionManager: PACSConnectionManager
    private let studyInstanceUID: String
    private let seriesInstanceUID: String
    private let cache = DICOMImageCache()
    
    private var instances: [InstanceResult] = []
    private var loadedFiles: [String: DICOMFile] = [:]
    
    var totalImages: Int { instances.count }
    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < totalImages - 1 }
    
    var currentFile: DICOMFile? {
        guard currentIndex < instances.count,
              let sopUID = instances[currentIndex].sopInstanceUID else {
            return nil
        }
        return loadedFiles[sopUID]
    }
    
    init(
        connectionManager: PACSConnectionManager,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) {
        self.connectionManager = connectionManager
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
    }
    
    func loadSeries() async {
        state = .loading
        
        do {
            // First, get the list of instances
            instances = try await connectionManager.findInstances(
                forStudy: studyInstanceUID,
                forSeries: seriesInstanceUID
            )
            
            // Sort by instance number if available
            instances.sort { ($0.instanceNumber ?? 0) < ($1.instanceNumber ?? 0) }
            
            // Load the first image
            if !instances.isEmpty {
                try await loadImage(at: 0)
            }
            
            state = .loaded
            
            // Preload nearby images in background
            Task {
                await preloadNearbyImages()
            }
            
        } catch {
            state = .error(error)
        }
    }
    
    func previousImage() {
        guard canGoBack else { return }
        goToImage(currentIndex - 1)
    }
    
    func nextImage() {
        guard canGoForward else { return }
        goToImage(currentIndex + 1)
    }
    
    func goToImage(_ index: Int) {
        guard index >= 0 && index < totalImages else { return }
        
        currentIndex = index
        
        // Load if not already loaded
        Task {
            if instances[index].sopInstanceUID != nil,
               loadedFiles[instances[index].sopInstanceUID!] == nil {
                try? await loadImage(at: index)
            }
            
            // Preload nearby images
            await preloadNearbyImages()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadImage(at index: Int) async throws {
        guard index < instances.count,
              let sopUID = instances[index].sopInstanceUID else {
            return
        }
        
        // Check cache first
        if let cached = await cache.retrieve(forKey: sopUID) {
            loadedFiles[sopUID] = cached
            return
        }
        
        // Retrieve from PACS
        let file = try await connectionManager.retrieveInstance(
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            sopInstanceUID: sopUID
        )
        
        loadedFiles[sopUID] = file
        
        // Store in cache
        try? await cache.store(file, forKey: sopUID)
    }
    
    private func preloadNearbyImages() async {
        // Preload 3 images ahead and 1 behind
        let indicesToPreload = [
            currentIndex - 1,
            currentIndex + 1,
            currentIndex + 2,
            currentIndex + 3
        ].filter { $0 >= 0 && $0 < totalImages }
        
        for index in indicesToPreload {
            guard let sopUID = instances[index].sopInstanceUID,
                  loadedFiles[sopUID] == nil else {
                continue
            }
            
            try? await loadImage(at: index)
        }
    }
}
```

### 4.4 Phase 4 Deliverables Checklist

- [ ] PixelDataRenderer integration
- [ ] Window/Level adjustment controls
- [ ] Multi-frame image navigation
- [ ] Series viewer with image navigation
- [ ] Zoom and pan functionality
- [ ] Image information overlay (patient, study info)
- [ ] Keyboard/gesture navigation
- [ ] Full-screen mode

---

## Phase 5: Advanced Features

### 5.1 Preset Window/Level Settings

```swift
/// Common window/level presets for different tissue types
enum WindowPreset: String, CaseIterable {
    case brain = "Brain"
    case subdural = "Subdural"
    case stroke = "Stroke"
    case bone = "Bone"
    case softTissue = "Soft Tissue"
    case lung = "Lung"
    case liver = "Liver"
    case abdomen = "Abdomen"
    case mediastinum = "Mediastinum"
    
    var settings: WindowSettings {
        switch self {
        case .brain:
            return WindowSettings(center: 40, width: 80)
        case .subdural:
            return WindowSettings(center: 75, width: 215)
        case .stroke:
            return WindowSettings(center: 32, width: 8)
        case .bone:
            return WindowSettings(center: 400, width: 1800)
        case .softTissue:
            return WindowSettings(center: 50, width: 400)
        case .lung:
            return WindowSettings(center: -600, width: 1500)
        case .liver:
            return WindowSettings(center: 60, width: 150)
        case .abdomen:
            return WindowSettings(center: 50, width: 400)
        case .mediastinum:
            return WindowSettings(center: 50, width: 350)
        }
    }
}

/// View for selecting window presets
struct WindowPresetPicker: View {
    @Binding var selectedPreset: WindowPreset?
    let onSelect: (WindowSettings) -> Void
    
    var body: some View {
        Menu {
            ForEach(WindowPreset.allCases, id: \.self) { preset in
                Button(preset.rawValue) {
                    selectedPreset = preset
                    onSelect(preset.settings)
                }
            }
        } label: {
            Label("Window Presets", systemImage: "slider.horizontal.3")
        }
    }
}
```

### 5.2 Measurements and Annotations

```swift
import SwiftUI

/// Types of measurements available
enum MeasurementType {
    case length
    case angle
    case area
    case hounsfield
}

/// A measurement annotation on an image
struct MeasurementAnnotation: Identifiable {
    let id = UUID()
    let type: MeasurementType
    let points: [CGPoint]
    let value: Double
    let unit: String
}

/// View for displaying and creating measurements
struct MeasurementOverlay: View {
    @Binding var annotations: [MeasurementAnnotation]
    @Binding var currentTool: MeasurementType?
    @State private var drawingPoints: [CGPoint] = []
    
    let pixelSpacing: (row: Double, column: Double)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Existing annotations
                ForEach(annotations) { annotation in
                    MeasurementShape(annotation: annotation)
                        .stroke(Color.yellow, lineWidth: 2)
                    
                    // Display value
                    if let midpoint = annotation.midpoint {
                        Text("\(annotation.value, specifier: "%.1f") \(annotation.unit)")
                            .font(.caption)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .position(midpoint)
                    }
                }
                
                // Current drawing
                if !drawingPoints.isEmpty {
                    Path { path in
                        path.addLines(drawingPoints)
                    }
                    .stroke(Color.yellow, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if currentTool != nil {
                            handleDrawing(at: value.location)
                        }
                    }
                    .onEnded { _ in
                        finishDrawing()
                    }
            )
        }
    }
    
    private func handleDrawing(at point: CGPoint) {
        drawingPoints.append(point)
    }
    
    private func finishDrawing() {
        guard let tool = currentTool, drawingPoints.count >= 2 else {
            drawingPoints.removeAll()
            return
        }
        
        let measurement = calculateMeasurement(
            type: tool,
            points: drawingPoints,
            pixelSpacing: pixelSpacing
        )
        
        annotations.append(measurement)
        drawingPoints.removeAll()
    }
    
    private func calculateMeasurement(
        type: MeasurementType,
        points: [CGPoint],
        pixelSpacing: (row: Double, column: Double)?
    ) -> MeasurementAnnotation {
        switch type {
        case .length:
            let length = calculateLength(points: points, pixelSpacing: pixelSpacing)
            return MeasurementAnnotation(
                type: .length,
                points: points,
                value: length,
                unit: pixelSpacing != nil ? "mm" : "px"
            )
        default:
            return MeasurementAnnotation(
                type: type,
                points: points,
                value: 0,
                unit: ""
            )
        }
    }
    
    private func calculateLength(
        points: [CGPoint],
        pixelSpacing: (row: Double, column: Double)?
    ) -> Double {
        guard points.count >= 2 else { return 0 }
        
        let p1 = points.first!
        let p2 = points.last!
        
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        if let spacing = pixelSpacing {
            // Convert to mm using pixel spacing
            let dxMm = Double(dx) * spacing.column
            let dyMm = Double(dy) * spacing.row
            return sqrt(dxMm * dxMm + dyMm * dyMm)
        } else {
            // Return in pixels
            let dxDouble = Double(dx)
            let dyDouble = Double(dy)
            return sqrt(dxDouble * dxDouble + dyDouble * dyDouble)
        }
    }
}

extension MeasurementAnnotation {
    var midpoint: CGPoint? {
        guard points.count >= 2 else { return nil }
        let p1 = points.first!
        let p2 = points.last!
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
}

struct MeasurementShape: Shape {
    let annotation: MeasurementAnnotation
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(annotation.points)
        return path
    }
}
```

### 5.3 Image Export

```swift
import UniformTypeIdentifiers

/// Service for exporting DICOM images
struct DICOMExportService {
    
    /// Exports a DICOM frame as PNG
    static func exportAsPNG(
        from dicomFile: DICOMFile,
        frameIndex: Int = 0,
        windowSettings: WindowSettings? = nil
    ) -> Data? {
        guard let cgImage = DICOMImageRenderingService.renderImage(
            from: dicomFile,
            frameIndex: frameIndex,
            windowSettings: windowSettings
        ) else {
            return nil
        }
        
        #if os(iOS) || os(visionOS)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.pngData()
        #elseif os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }
    
    /// Exports a DICOM frame as JPEG
    static func exportAsJPEG(
        from dicomFile: DICOMFile,
        frameIndex: Int = 0,
        windowSettings: WindowSettings? = nil,
        quality: Double = 0.9
    ) -> Data? {
        guard let cgImage = DICOMImageRenderingService.renderImage(
            from: dicomFile,
            frameIndex: frameIndex,
            windowSettings: windowSettings
        ) else {
            return nil
        }
        
        #if os(iOS) || os(visionOS)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: quality)
        #elseif os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }
    
    /// Saves raw DICOM file to disk
    static func saveDICOMFile(
        _ dicomFile: DICOMFile,
        to url: URL
    ) throws {
        let data = try dicomFile.write()
        try data.write(to: url)
    }
}
```

### 5.4 DICOM Information Panel

```swift
import SwiftUI
import DICOMKit

/// View displaying DICOM metadata
struct DICOMInfoPanel: View {
    let dicomFile: DICOMFile
    
    var body: some View {
        List {
            // Patient Information
            Section("Patient") {
                InfoRow(label: "Name", value: dicomFile.dataSet.string(for: .patientName))
                InfoRow(label: "ID", value: dicomFile.dataSet.string(for: .patientID))
                InfoRow(label: "Birth Date", value: dicomFile.dataSet.string(for: .patientBirthDate))
                InfoRow(label: "Sex", value: dicomFile.dataSet.string(for: .patientSex))
            }
            
            // Study Information
            Section("Study") {
                InfoRow(label: "Date", value: dicomFile.dataSet.string(for: .studyDate))
                InfoRow(label: "Time", value: dicomFile.dataSet.string(for: .studyTime))
                InfoRow(label: "Description", value: dicomFile.dataSet.string(for: .studyDescription))
                InfoRow(label: "Accession #", value: dicomFile.dataSet.string(for: .accessionNumber))
                InfoRow(label: "Study UID", value: dicomFile.dataSet.string(for: .studyInstanceUID))
            }
            
            // Series Information
            Section("Series") {
                InfoRow(label: "Number", value: dicomFile.dataSet.string(for: .seriesNumber))
                InfoRow(label: "Modality", value: dicomFile.dataSet.string(for: .modality))
                InfoRow(label: "Description", value: dicomFile.dataSet.string(for: .seriesDescription))
                InfoRow(label: "Body Part", value: dicomFile.dataSet.string(for: .bodyPartExamined))
                InfoRow(label: "Series UID", value: dicomFile.dataSet.string(for: .seriesInstanceUID))
            }
            
            // Image Information
            Section("Image") {
                InfoRow(label: "Instance #", value: dicomFile.dataSet.string(for: .instanceNumber))
                InfoRow(label: "Rows", value: dicomFile.dataSet.string(for: .rows))
                InfoRow(label: "Columns", value: dicomFile.dataSet.string(for: .columns))
                InfoRow(label: "Bits Stored", value: dicomFile.dataSet.string(for: .bitsStored))
                InfoRow(label: "Frames", value: dicomFile.dataSet.string(for: .numberOfFrames) ?? "1")
                InfoRow(label: "Photometric", value: dicomFile.dataSet.string(for: .photometricInterpretation))
            }
            
            // Equipment Information
            Section("Equipment") {
                InfoRow(label: "Manufacturer", value: dicomFile.dataSet.string(for: .manufacturer))
                InfoRow(label: "Model", value: dicomFile.dataSet.string(for: .manufacturerModelName))
                InfoRow(label: "Station", value: dicomFile.dataSet.string(for: .stationName))
                InfoRow(label: "Institution", value: dicomFile.dataSet.string(for: .institutionName))
            }
        }
        .navigationTitle("DICOM Information")
    }
}

struct InfoRow: View {
    let label: String
    let value: String?
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value ?? "—")
                .lineLimit(1)
        }
    }
}
```

### 5.5 Phase 5 Deliverables Checklist

- [ ] Window/level presets (CT tissue types)
- [ ] Length measurement tool
- [ ] Angle measurement tool
- [ ] ROI statistics (mean, std dev)
- [ ] Image export (PNG, JPEG)
- [ ] DICOM tag browser
- [ ] Print support
- [ ] Study comparison view
- [ ] 3D MPR reconstruction (advanced)
- [ ] Hanging protocols

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        DICOM Viewer App                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Views      │  │  ViewModels  │  │      Services        │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────────────┤  │
│  │ PatientList  │  │ PatientVM    │  │ PACSConnectionMgr    │  │
│  │ StudyList    │◄─┤ StudyVM      │◄─┤ DICOMImageCache      │  │
│  │ SeriesViewer │  │ SeriesVM     │  │ StorageSCPManager    │  │
│  │ ImageViewer  │  │ ImageVM      │  │ DICOMRenderingService│  │
│  │ InfoPanel    │  │              │  │ DICOMExportService   │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                         DICOMKit                                │
├──────────────┬──────────────┬──────────────┬───────────────────┤
│  DICOMCore   │ DICOMNetwork │   DICOMKit   │  DICOMDictionary  │
├──────────────┼──────────────┼──────────────┼───────────────────┤
│ - Tag        │ - C-ECHO     │ - DICOMFile  │ - Tag Dictionary  │
│ - VR         │ - C-FIND     │ - DataSet    │ - UID Dictionary  │
│ - DataElement│ - C-MOVE     │ - PixelData  │                   │
│ - PixelData  │ - C-GET      │ - Renderer   │                   │
│ - Codecs     │ - C-STORE    │              │                   │
│              │ - TLS        │              │                   │
└──────────────┴──────────────┴──────────────┴───────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   PACS Server   │
                    │                 │
                    │ ┌─────────────┐ │
                    │ │  Patients   │ │
                    │ │  Studies    │ │
                    │ │  Series     │ │
                    │ │  Instances  │ │
                    │ └─────────────┘ │
                    └─────────────────┘
```

---

## Security Considerations

### HIPAA Compliance

1. **Data Protection**
   - Always use TLS for PACS connections in production
   - Encrypt cached DICOM files on disk
   - Clear cache on logout or app termination

2. **Access Control**
   - Implement user authentication
   - Use DICOM User Identity negotiation
   - Log all access to patient data

3. **Audit Logging**
   - Use DICOMKit's AuditLogger for ATNA compliance
   - Log queries, retrievals, and views
   - Store audit logs securely

### Example TLS Configuration

```swift
// Production TLS configuration
let tlsConfig = TLSConfiguration.default

// With certificate pinning (recommended)
let pinnedConfig = TLSConfiguration(
    trustRoots: .pinnedCertificates([certificateData]),
    minimumTLSVersion: .tlsProtocol13
)

// For development only (self-signed certs)
let devConfig = TLSConfiguration.insecure
```

### Example Audit Logging

```swift
import DICOMKit

// Configure audit logging
let auditLogger = AuditLogger(handlers: [
    ConsoleAuditHandler(),
    FileAuditHandler(directory: auditLogDirectory)
])

// Log a study access event
auditLogger.log(
    eventType: .instanceAccessed,
    patientID: "123456",
    studyInstanceUID: studyUID,
    seriesInstanceUID: seriesUID,
    sopInstanceUID: instanceUID,
    userID: currentUser.id,
    outcome: .success
)
```

---

## Summary

This implementation plan provides a structured approach to building a DICOM Viewer using DICOMKit:

| Phase | Focus | Key Deliverables |
|-------|-------|------------------|
| 1 | Setup | PACS configuration, connectivity testing |
| 2 | Discovery | Patient/Study/Series browsing (C-FIND) |
| 3 | Retrieval | Image download (C-GET/C-MOVE), caching |
| 4 | Display | Image rendering, navigation, window/level |
| 5 | Advanced | Measurements, export, metadata browser |

Each phase builds upon the previous, allowing for incremental development and testing. The code examples provided use DICOMKit's actual APIs and can be directly integrated into your application.

For detailed API documentation, refer to:
- [DICOMKit README](README.md)
- [DICOMKit Milestones](MILESTONES.md)
- [DICOM Camera Features](DICOM_CAMERA_FEATURES.md)
