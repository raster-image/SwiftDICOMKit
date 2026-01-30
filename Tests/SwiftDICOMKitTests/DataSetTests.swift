import Testing
import Foundation
@testable import SwiftDICOMKit

@Suite("DataSet Tests")
struct DataSetTests {
    
    @Test("Empty DataSet creation")
    func testEmptyDataSet() {
        let dataSet = DataSet()
        #expect(dataSet.count == 0)
        #expect(dataSet.tags.isEmpty)
    }
    
    @Test("DataSet creation from elements")
    func testDataSetFromElements() {
        let element1 = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        let element2 = DataElement(
            tag: .patientID,
            vr: .LO,
            length: 6,
            valueData: "123456".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element1, element2])
        #expect(dataSet.count == 2)
        #expect(dataSet[.patientName] != nil)
        #expect(dataSet[.patientID] != nil)
    }
    
    @Test("DataSet subscript access")
    func testDataSetSubscript() {
        var dataSet = DataSet()
        
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        dataSet[.patientName] = element
        #expect(dataSet[.patientName] != nil)
        #expect(dataSet[.patientName]?.tag == .patientName)
    }
    
    @Test("DataSet string extraction")
    func testDataSetStringExtraction() {
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let name = dataSet.string(for: .patientName)
        #expect(name == "DOE^JOHN")
    }
    
    @Test("DataSet iteration")
    func testDataSetIteration() {
        let element1 = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        
        let element2 = DataElement(
            tag: .patientID,
            vr: .LO,
            length: 6,
            valueData: "123456".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element1, element2])
        
        var count = 0
        for _ in dataSet {
            count += 1
        }
        
        #expect(count == 2)
    }
    
    @Test("DataSet numeric value extraction")
    func testDataSetNumericExtraction() {
        // Create elements with various numeric types
        var uint16Data = Data()
        uint16Data.append(contentsOf: [0x64, 0x00]) // 100
        let seriesElement = DataElement(
            tag: .seriesNumber,
            vr: .US,
            length: 2,
            valueData: uint16Data
        )
        
        var float64Data = Data()
        let sliceThickness: Float64 = 5.0
        withUnsafeBytes(of: sliceThickness.bitPattern) { float64Data.append(contentsOf: $0) }
        let sliceElement = DataElement(
            tag: .sliceThickness,
            vr: .FD,
            length: 8,
            valueData: float64Data
        )
        
        let dataSet = DataSet(elements: [seriesElement, sliceElement])
        
        // Test single value extraction
        #expect(dataSet.uint16(for: .seriesNumber) == 100)
        #expect(dataSet.float64(for: .sliceThickness) == 5.0)
    }
    
    @Test("DataSet array value extraction")
    func testDataSetArrayExtraction() {
        // Create element with multiple UInt16 values
        var data = Data()
        data.append(contentsOf: [0x64, 0x00]) // 100
        data.append(contentsOf: [0xC8, 0x00]) // 200
        data.append(contentsOf: [0x2C, 0x01]) // 300
        
        let element = DataElement(
            tag: Tag(group: 0x0028, element: 0x0010),
            vr: .US,
            length: 6,
            valueData: data
        )
        
        let dataSet = DataSet(elements: [element])
        let values = dataSet.uint16s(for: Tag(group: 0x0028, element: 0x0010))
        
        #expect(values?.count == 3)
        #expect(values?[0] == 100)
        #expect(values?[1] == 200)
        #expect(values?[2] == 300)
    }
    
    // MARK: - Date/Time Value Access Tests
    
    @Test("DataSet DICOM Date extraction")
    func testDataSetDateExtraction() {
        let element = DataElement(
            tag: .studyDate,
            vr: .DA,
            length: 8,
            valueData: "20250130".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let date = dataSet.date(for: .studyDate)
        
        #expect(date != nil)
        #expect(date?.year == 2025)
        #expect(date?.month == 1)
        #expect(date?.day == 30)
    }
    
    @Test("DataSet DICOM Time extraction")
    func testDataSetTimeExtraction() {
        let element = DataElement(
            tag: .studyTime,
            vr: .TM,
            length: 6,
            valueData: "143025".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let time = dataSet.time(for: .studyTime)
        
        #expect(time != nil)
        #expect(time?.hour == 14)
        #expect(time?.minute == 30)
        #expect(time?.second == 25)
    }
    
    @Test("DataSet DICOM DateTime extraction")
    func testDataSetDateTimeExtraction() {
        // Create a DT element - using Acquisition DateTime tag
        let element = DataElement(
            tag: Tag(group: 0x0008, element: 0x002A),
            vr: .DT,
            length: 19,
            valueData: "20250130143025+0530".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let dateTime = dataSet.dateTime(for: Tag(group: 0x0008, element: 0x002A))
        
        #expect(dateTime != nil)
        #expect(dateTime?.year == 2025)
        #expect(dateTime?.month == 1)
        #expect(dateTime?.day == 30)
        #expect(dateTime?.hour == 14)
        #expect(dateTime?.minute == 30)
        #expect(dateTime?.timezoneOffsetMinutes == 330)
    }
    
    @Test("DataSet Foundation Date extraction")
    func testDataSetFoundationDateExtraction() {
        let element = DataElement(
            tag: .studyDate,
            vr: .DA,
            length: 8,
            valueData: "20250130".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let date = dataSet.foundationDate(for: .studyDate)
        
        #expect(date != nil)
    }
    
    @Test("DataSet date returns nil for missing tag")
    func testDataSetDateMissingTag() {
        let dataSet = DataSet()
        
        #expect(dataSet.date(for: .studyDate) == nil)
        #expect(dataSet.time(for: .studyTime) == nil)
        #expect(dataSet.dateTime(for: Tag(group: 0x0008, element: 0x002A)) == nil)
        #expect(dataSet.foundationDate(for: .studyDate) == nil)
    }
    
    // MARK: - Age String Value Access Tests
    
    @Test("DataSet DICOM Age String extraction")
    func testDataSetAgeExtraction() {
        let element = DataElement(
            tag: .patientAge,
            vr: .AS,
            length: 4,
            valueData: "018Y".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let age = dataSet.age(for: .patientAge)
        
        #expect(age != nil)
        #expect(age?.value == 18)
        #expect(age?.unit == .years)
        #expect(age?.humanReadable == "18 years")
    }
    
    @Test("DataSet age returns nil for missing tag")
    func testDataSetAgeMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.age(for: .patientAge) == nil)
    }
    
    // MARK: - Decimal String Value Access Tests
    
    @Test("DataSet DICOM Decimal String extraction")
    func testDataSetDecimalStringExtraction() {
        let element = DataElement(
            tag: .sliceThickness,
            vr: .DS,
            length: 3,
            valueData: "2.5".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let ds = dataSet.decimalString(for: .sliceThickness)
        
        #expect(ds != nil)
        #expect(ds?.value == 2.5)
    }
    
    @Test("DataSet DICOM Decimal String multiple values extraction")
    func testDataSetDecimalStringsExtraction() {
        let element = DataElement(
            tag: .pixelSpacing,
            vr: .DS,
            length: 13,
            valueData: "0.3125\\0.3125".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let values = dataSet.decimalStrings(for: .pixelSpacing)
        
        #expect(values != nil)
        #expect(values?.count == 2)
        #expect(values?[0].value == 0.3125)
        #expect(values?[1].value == 0.3125)
    }
    
    @Test("DataSet decimal string returns nil for missing tag")
    func testDataSetDecimalStringMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.decimalString(for: .sliceThickness) == nil)
        #expect(dataSet.decimalStrings(for: .pixelSpacing) == nil)
    }
    
    // MARK: - Integer String Value Access Tests
    
    @Test("DataSet DICOM Integer String extraction")
    func testDataSetIntegerStringExtraction() {
        let element = DataElement(
            tag: .instanceNumber,
            vr: .IS,
            length: 1,
            valueData: "1".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let is_value = dataSet.integerString(for: .instanceNumber)
        
        #expect(is_value != nil)
        #expect(is_value?.value == 1)
    }
    
    @Test("DataSet DICOM Integer String multiple values extraction")
    func testDataSetIntegerStringsExtraction() {
        let element = DataElement(
            tag: Tag(group: 0x0020, element: 0x0013),
            vr: .IS,
            length: 5,
            valueData: "1\\2\\3".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let values = dataSet.integerStrings(for: Tag(group: 0x0020, element: 0x0013))
        
        #expect(values != nil)
        #expect(values?.count == 3)
        #expect(values?[0].value == 1)
        #expect(values?[1].value == 2)
        #expect(values?[2].value == 3)
    }
    
    @Test("DataSet integer string returns nil for missing tag")
    func testDataSetIntegerStringMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.integerString(for: .instanceNumber) == nil)
        #expect(dataSet.integerStrings(for: Tag(group: 0x0020, element: 0x0013)) == nil)
    }
    
    @Test("DataSet sequence access methods")
    func testDataSetSequenceAccess() {
        // Create a sequence element with items
        let innerElement = DataElement(
            tag: Tag(group: 0x0008, element: 0x0100),
            vr: .SH,
            length: 5,
            valueData: "12345".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [innerElement])
        
        let sequenceElement = DataElement(
            tag: .procedureCodeSequence,
            vr: .SQ,
            length: 0xFFFFFFFF,
            valueData: Data(),
            sequenceItems: [item]
        )
        
        let dataSet = DataSet(elements: [sequenceElement])
        
        #expect(dataSet.isSequence(tag: .procedureCodeSequence) == true)
        #expect(dataSet.sequenceItemCount(for: .procedureCodeSequence) == 1)
        #expect(dataSet.sequence(for: .procedureCodeSequence)?.count == 1)
        #expect(dataSet.firstSequenceItem(for: .procedureCodeSequence) != nil)
    }
    
    // MARK: - Person Name Value Access Tests
    
    @Test("DataSet DICOM Person Name extraction")
    func testDataSetPersonNameExtraction() {
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 23,
            valueData: "Doe^John^Robert^Dr.^Jr.".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let name = dataSet.personName(for: .patientName)
        
        #expect(name != nil)
        #expect(name?.familyName == "Doe")
        #expect(name?.givenName == "John")
        #expect(name?.middleName == "Robert")
        #expect(name?.namePrefix == "Dr.")
        #expect(name?.nameSuffix == "Jr.")
        #expect(name?.formattedName == "Dr. John Robert Doe Jr.")
    }
    
    @Test("DataSet DICOM Person Name multiple values extraction")
    func testDataSetPersonNamesExtraction() {
        let element = DataElement(
            tag: .patientName,
            vr: .PN,
            length: 19,
            valueData: "Doe^John\\Smith^Jane".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element])
        let names = dataSet.personNames(for: .patientName)
        
        #expect(names != nil)
        #expect(names?.count == 2)
        #expect(names?[0].familyName == "Doe")
        #expect(names?[0].givenName == "John")
        #expect(names?[1].familyName == "Smith")
        #expect(names?[1].givenName == "Jane")
    }
    
    @Test("DataSet person name returns nil for missing tag")
    func testDataSetPersonNameMissingTag() {
        let dataSet = DataSet()
        #expect(dataSet.personName(for: .patientName) == nil)
        #expect(dataSet.personNames(for: .patientName) == nil)
    }
    
    // MARK: - Pagination Support Tests
    
    @Test("DataSet elements(from:count:) basic pagination")
    func testDataSetElementsFromCount() {
        // Create a data set with 5 elements
        let elements = createTestElements(count: 5)
        let dataSet = DataSet(elements: elements)
        
        // Get first 3 elements
        let first3 = dataSet.elements(from: 0, count: 3)
        #expect(first3.count == 3)
        
        // Get next 2 elements
        let next2 = dataSet.elements(from: 3, count: 3)
        #expect(next2.count == 2)
    }
    
    @Test("DataSet elements(from:count:) with invalid parameters")
    func testDataSetElementsFromCountInvalid() {
        let elements = createTestElements(count: 5)
        let dataSet = DataSet(elements: elements)
        
        // Negative start index
        #expect(dataSet.elements(from: -1, count: 3).isEmpty)
        
        // Zero count
        #expect(dataSet.elements(from: 0, count: 0).isEmpty)
        
        // Negative count
        #expect(dataSet.elements(from: 0, count: -1).isEmpty)
        
        // Start beyond range
        #expect(dataSet.elements(from: 100, count: 3).isEmpty)
    }
    
    @Test("DataSet elements(page:pageSize:) pagination")
    func testDataSetPagePagination() {
        // Create a data set with 25 elements
        let elements = createTestElements(count: 25)
        let dataSet = DataSet(elements: elements)
        
        // Get page 0 with page size 10
        let page0 = dataSet.elements(page: 0, pageSize: 10)
        #expect(page0.count == 10)
        
        // Get page 1 with page size 10
        let page1 = dataSet.elements(page: 1, pageSize: 10)
        #expect(page1.count == 10)
        
        // Get page 2 with page size 10 (should have only 5 elements)
        let page2 = dataSet.elements(page: 2, pageSize: 10)
        #expect(page2.count == 5)
        
        // Get page 3 (should be empty)
        let page3 = dataSet.elements(page: 3, pageSize: 10)
        #expect(page3.isEmpty)
    }
    
    @Test("DataSet elements(page:pageSize:) with invalid parameters")
    func testDataSetPagePaginationInvalid() {
        let elements = createTestElements(count: 5)
        let dataSet = DataSet(elements: elements)
        
        // Negative page
        #expect(dataSet.elements(page: -1, pageSize: 10).isEmpty)
        
        // Zero page size
        #expect(dataSet.elements(page: 0, pageSize: 0).isEmpty)
        
        // Negative page size
        #expect(dataSet.elements(page: 0, pageSize: -1).isEmpty)
    }
    
    @Test("DataSet next(_:after:) pagination")
    func testDataSetNextAfterTag() {
        // Create a data set with known tags in order
        let element1 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0010),
            vr: .CS,
            length: 3,
            valueData: "CT ".data(using: .utf8)!
        )
        let element2 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0020),
            vr: .DA,
            length: 8,
            valueData: "20250130".data(using: .utf8)!
        )
        let element3 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0030),
            vr: .TM,
            length: 6,
            valueData: "120000".data(using: .utf8)!
        )
        let element4 = DataElement(
            tag: Tag(group: 0x0010, element: 0x0010),
            vr: .PN,
            length: 8,
            valueData: "DOE^JOHN".data(using: .utf8)!
        )
        let element5 = DataElement(
            tag: Tag(group: 0x0010, element: 0x0020),
            vr: .LO,
            length: 6,
            valueData: "123456".data(using: .utf8)!
        )
        
        let dataSet = DataSet(elements: [element1, element2, element3, element4, element5])
        
        // Get next 2 elements after element2's tag
        let next2 = dataSet.next(2, after: Tag(group: 0x0008, element: 0x0020))
        #expect(next2.count == 2)
        #expect(next2[0].tag == Tag(group: 0x0008, element: 0x0030))
        #expect(next2[1].tag == Tag(group: 0x0010, element: 0x0010))
        
        // Get next 10 after element3 (should return only 2 remaining)
        let remaining = dataSet.next(10, after: Tag(group: 0x0008, element: 0x0030))
        #expect(remaining.count == 2)
        
        // Get next after last element (should be empty)
        let beyondEnd = dataSet.next(10, after: Tag(group: 0x0010, element: 0x0020))
        #expect(beyondEnd.isEmpty)
    }
    
    @Test("DataSet next(_:after:) with default count")
    func testDataSetNextDefaultCount() {
        let elements = createTestElements(count: 15)
        let dataSet = DataSet(elements: elements)
        
        // The default count should be 10
        let first = dataSet.first()
        let firstTag = first.last!.tag
        
        let next = dataSet.next(after: firstTag)
        #expect(next.count == 5) // 15 - 10 = 5 remaining after first 10
    }
    
    @Test("DataSet first(_:) method")
    func testDataSetFirst() {
        let elements = createTestElements(count: 25)
        let dataSet = DataSet(elements: elements)
        
        // Get first 10 (default)
        let first10 = dataSet.first()
        #expect(first10.count == 10)
        
        // Get first 5
        let first5 = dataSet.first(5)
        #expect(first5.count == 5)
        
        // Get first 100 (should return all 25)
        let firstAll = dataSet.first(100)
        #expect(firstAll.count == 25)
    }
    
    @Test("DataSet first(_:) with invalid count")
    func testDataSetFirstInvalid() {
        let elements = createTestElements(count: 5)
        let dataSet = DataSet(elements: elements)
        
        // Zero count
        #expect(dataSet.first(0).isEmpty)
        
        // Negative count
        #expect(dataSet.first(-1).isEmpty)
    }
    
    @Test("DataSet pageCount(pageSize:) calculation")
    func testDataSetPageCount() {
        let elements = createTestElements(count: 25)
        let dataSet = DataSet(elements: elements)
        
        #expect(dataSet.pageCount(pageSize: 10) == 3)  // 25 elements / 10 = 3 pages
        #expect(dataSet.pageCount(pageSize: 5) == 5)   // 25 elements / 5 = 5 pages
        #expect(dataSet.pageCount(pageSize: 25) == 1)  // 25 elements / 25 = 1 page
        #expect(dataSet.pageCount(pageSize: 30) == 1)  // 25 elements / 30 = 1 page
        #expect(dataSet.pageCount(pageSize: 0) == 0)   // Invalid page size
    }
    
    @Test("DataSet pagination on empty data set")
    func testDataSetPaginationEmpty() {
        let dataSet = DataSet()
        
        #expect(dataSet.elements(from: 0, count: 10).isEmpty)
        #expect(dataSet.elements(page: 0, pageSize: 10).isEmpty)
        #expect(dataSet.first().isEmpty)
        #expect(dataSet.next(after: Tag(group: 0x0010, element: 0x0010)).isEmpty)
        #expect(dataSet.pageCount(pageSize: 10) == 0)
    }
    
    // MARK: - Test Helpers
    
    /// Creates test data elements with sequential tags
    private func createTestElements(count: Int) -> [DataElement] {
        return (0..<count).map { index in
            let group = UInt16(0x0010 + index / 256)
            let element = UInt16(0x0010 + (index % 256))
            return DataElement(
                tag: Tag(group: group, element: element),
                vr: .LO,
                length: 4,
                valueData: "TEST".data(using: .utf8)!
            )
        }
    }
}
