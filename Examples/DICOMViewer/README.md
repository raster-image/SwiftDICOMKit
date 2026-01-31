# DICOMViewer Example Application

An example SwiftUI application demonstrating the capabilities of DICOMKit for browsing and viewing DICOM images from PACS servers.

## Features

### Phase 1 (Current)
- ✅ PACS server configuration and management
- ✅ Connection testing with C-ECHO verification
- ✅ Patient search with wildcards support
- ✅ Patient → Study → Series hierarchy navigation
- ✅ Multi-platform support (iOS, macOS, visionOS)

### Phase 2 (Coming Soon)
- Image retrieval from PACS (C-GET)
- DICOM image rendering
- Image manipulation (windowing, pan, zoom)

## Project Structure

```
DICOMViewer/
├── App/
│   ├── DICOMViewerApp.swift      # Main app entry point
│   └── AppState.swift            # Global state management
├── Models/
│   ├── PACSServer.swift          # PACS server configuration
│   ├── PatientSearchCriteria.swift # Search parameters
│   └── QueryResultModels.swift   # Display models
├── Views/
│   ├── ContentView.swift         # Root navigation view
│   ├── ServerListView.swift      # Server list and management
│   ├── ServerConfigView.swift    # Server configuration form
│   ├── PatientSearchView.swift   # Patient search form
│   ├── StudyListView.swift       # Studies for a patient
│   └── SeriesListView.swift      # Series within a study
├── ViewModels/
│   └── (Coming in Phase 2)
├── Services/
│   ├── ServerStorageService.swift    # Server persistence
│   ├── ConnectionTestService.swift   # C-ECHO testing
│   └── PACSQueryService.swift        # PACS queries
└── Resources/
    └── (Assets and localization)
```

## Requirements

- iOS 17.0+
- macOS 14.0+
- visionOS 1.0+
- Xcode 15.0+
- Swift 5.9+

## Getting Started

### Using Xcode

1. Open the main DICOMKit package in Xcode
2. Create a new iOS/macOS App target
3. Add the DICOMViewer files to your target
4. Add DICOMKit package dependency
5. Import required modules:
   ```swift
   import DICOMKit
   import DICOMCore
   import DICOMNetwork
   ```

### Configuration

1. Launch the app
2. Tap "+" to add a new PACS server
3. Enter connection details:
   - Server name (display name)
   - Host address (IP or hostname)
   - Port (typically 104 or 11112)
   - Called AE Title (remote PACS)
   - Calling AE Title (this app)
4. Test the connection
5. Save and start searching

## Architecture

The application follows the **MVVM** (Model-View-ViewModel) architecture pattern:

- **Models**: Data structures for PACS servers, search criteria, and query results
- **Views**: SwiftUI views for the user interface
- **ViewModels**: Business logic and state management (expanded in Phase 2)
- **Services**: Network and persistence services

### State Management

Uses Swift's new `@Observable` macro for reactive state management:

```swift
@Observable
final class AppState {
    var servers: [PACSServer] = []
    var selectedServer: PACSServer?
    var patientResults: [PatientDisplayModel] = []
    // ...
}
```

### Navigation

Uses SwiftUI's `NavigationStack` with type-safe navigation paths:

```swift
enum AppScreen: Hashable {
    case serverList
    case patientSearch(server: PACSServer)
    case studyList(server: PACSServer, patient: PatientDisplayModel)
    case seriesList(server: PACSServer, study: StudyDisplayModel)
    case imageViewer(server: PACSServer, series: SeriesDisplayModel)
}
```

## Usage Examples

### Adding a Server

```swift
let server = PACSServer(
    name: "Hospital PACS",
    host: "pacs.hospital.com",
    port: 11112,
    calledAETitle: "PACS",
    callingAETitle: "DICOMVIEWER"
)

try ServerStorageService.shared.addServer(server)
```

### Testing Connection

```swift
let status = await ConnectionTestService.shared.testConnection(to: server)
if status.success {
    print("Connected in \(status.responseTimeMs ?? 0)ms")
} else {
    print("Failed: \(status.errorMessage ?? "Unknown error")")
}
```

### Searching Patients

```swift
let criteria = PatientSearchCriteria(
    patientName: "SMITH*",
    sex: .male
)

let patients = try await PACSQueryService.shared.findPatients(
    on: server,
    matching: criteria
)
```

## License

This example is part of DICOMKit and shares its MIT license.
