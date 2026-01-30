import Testing
import Foundation
@testable import DICOMCore

@Suite("SequenceItem Tests")
struct SequenceItemTests {
    
    @Test("Empty SequenceItem creation")
    func testEmptySequenceItem() {
        let item = SequenceItem()
        #expect(item.count == 0)
        #expect(item.tags.isEmpty)
        #expect(item.allElements.isEmpty)
    }
    
    @Test("SequenceItem creation from element array")
    func testSequenceItemFromArray() {
        let element1 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0100),
            vr: .SH,
            length: 5,
            valueData: "12345".data(using: .utf8)!
        )
        
        let element2 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0102),
            vr: .SH,
            length: 4,
            valueData: "TEST".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [element1, element2])
        #expect(item.count == 2)
        #expect(item[Tag(group: 0x0008, element: 0x0100)] != nil)
        #expect(item[Tag(group: 0x0008, element: 0x0102)] != nil)
    }
    
    @Test("SequenceItem string extraction")
    func testSequenceItemStringExtraction() {
        let element = DataElement(
            tag: Tag(group: 0x0008, element: 0x0100),
            vr: .SH,
            length: 5,
            valueData: "12345".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [element])
        let value = item.string(for: Tag(group: 0x0008, element: 0x0100))
        #expect(value == "12345")
    }
    
    // MARK: - Pagination Support Tests
    
    @Test("SequenceItem elements(from:count:) basic pagination")
    func testSequenceItemElementsFromCount() {
        // Create a sequence item with 5 elements
        let elements = createTestElements(count: 5)
        let item = SequenceItem(elements: elements)
        
        // Get first 3 elements
        let first3 = item.elements(from: 0, count: 3)
        #expect(first3.count == 3)
        
        // Get next 2 elements
        let next2 = item.elements(from: 3, count: 3)
        #expect(next2.count == 2)
    }
    
    @Test("SequenceItem elements(from:count:) with invalid parameters")
    func testSequenceItemElementsFromCountInvalid() {
        let elements = createTestElements(count: 5)
        let item = SequenceItem(elements: elements)
        
        // Negative start index
        #expect(item.elements(from: -1, count: 3).isEmpty)
        
        // Zero count
        #expect(item.elements(from: 0, count: 0).isEmpty)
        
        // Negative count
        #expect(item.elements(from: 0, count: -1).isEmpty)
        
        // Start beyond range
        #expect(item.elements(from: 100, count: 3).isEmpty)
    }
    
    @Test("SequenceItem elements(page:pageSize:) pagination")
    func testSequenceItemPagePagination() {
        // Create a sequence item with 25 elements
        let elements = createTestElements(count: 25)
        let item = SequenceItem(elements: elements)
        
        // Get page 0 with page size 10
        let page0 = item.elements(page: 0, pageSize: 10)
        #expect(page0.count == 10)
        
        // Get page 1 with page size 10
        let page1 = item.elements(page: 1, pageSize: 10)
        #expect(page1.count == 10)
        
        // Get page 2 with page size 10 (should have only 5 elements)
        let page2 = item.elements(page: 2, pageSize: 10)
        #expect(page2.count == 5)
        
        // Get page 3 (should be empty)
        let page3 = item.elements(page: 3, pageSize: 10)
        #expect(page3.isEmpty)
    }
    
    @Test("SequenceItem elements(page:pageSize:) with invalid parameters")
    func testSequenceItemPagePaginationInvalid() {
        let elements = createTestElements(count: 5)
        let item = SequenceItem(elements: elements)
        
        // Negative page
        #expect(item.elements(page: -1, pageSize: 10).isEmpty)
        
        // Zero page size
        #expect(item.elements(page: 0, pageSize: 0).isEmpty)
        
        // Negative page size
        #expect(item.elements(page: 0, pageSize: -1).isEmpty)
    }
    
    @Test("SequenceItem next(_:after:) pagination")
    func testSequenceItemNextAfterTag() {
        // Create a sequence item with known tags in order
        let element1 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0100),
            vr: .SH,
            length: 5,
            valueData: "CODE1".data(using: .utf8)!
        )
        let element2 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0102),
            vr: .SH,
            length: 5,
            valueData: "CODE2".data(using: .utf8)!
        )
        let element3 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0104),
            vr: .LO,
            length: 5,
            valueData: "TEXT1".data(using: .utf8)!
        )
        let element4 = DataElement(
            tag: Tag(group: 0x0008, element: 0x0106),
            vr: .LO,
            length: 5,
            valueData: "TEXT2".data(using: .utf8)!
        )
        
        let item = SequenceItem(elements: [element1, element2, element3, element4])
        
        // Get next 2 elements after element1's tag
        let next2 = item.next(2, after: Tag(group: 0x0008, element: 0x0100))
        #expect(next2.count == 2)
        #expect(next2[0].tag == Tag(group: 0x0008, element: 0x0102))
        #expect(next2[1].tag == Tag(group: 0x0008, element: 0x0104))
        
        // Get next 10 after element2 (should return only 2 remaining)
        let remaining = item.next(10, after: Tag(group: 0x0008, element: 0x0102))
        #expect(remaining.count == 2)
        
        // Get next after last element (should be empty)
        let beyondEnd = item.next(10, after: Tag(group: 0x0008, element: 0x0106))
        #expect(beyondEnd.isEmpty)
    }
    
    @Test("SequenceItem next(_:after:) with default count")
    func testSequenceItemNextDefaultCount() {
        let elements = createTestElements(count: 15)
        let item = SequenceItem(elements: elements)
        
        // The default count should be 10
        let first = item.first()
        let firstTag = first.last!.tag
        
        let next = item.next(after: firstTag)
        #expect(next.count == 5) // 15 - 10 = 5 remaining after first 10
    }
    
    @Test("SequenceItem first(_:) method")
    func testSequenceItemFirst() {
        let elements = createTestElements(count: 25)
        let item = SequenceItem(elements: elements)
        
        // Get first 10 (default)
        let first10 = item.first()
        #expect(first10.count == 10)
        
        // Get first 5
        let first5 = item.first(5)
        #expect(first5.count == 5)
        
        // Get first 100 (should return all 25)
        let firstAll = item.first(100)
        #expect(firstAll.count == 25)
    }
    
    @Test("SequenceItem first(_:) with invalid count")
    func testSequenceItemFirstInvalid() {
        let elements = createTestElements(count: 5)
        let item = SequenceItem(elements: elements)
        
        // Zero count
        #expect(item.first(0).isEmpty)
        
        // Negative count
        #expect(item.first(-1).isEmpty)
    }
    
    @Test("SequenceItem pageCount(pageSize:) calculation")
    func testSequenceItemPageCount() {
        let elements = createTestElements(count: 25)
        let item = SequenceItem(elements: elements)
        
        #expect(item.pageCount(pageSize: 10) == 3)  // 25 elements / 10 = 3 pages
        #expect(item.pageCount(pageSize: 5) == 5)   // 25 elements / 5 = 5 pages
        #expect(item.pageCount(pageSize: 25) == 1)  // 25 elements / 25 = 1 page
        #expect(item.pageCount(pageSize: 30) == 1)  // 25 elements / 30 = 1 page
        #expect(item.pageCount(pageSize: 0) == 0)   // Invalid page size
    }
    
    @Test("SequenceItem pagination on empty item")
    func testSequenceItemPaginationEmpty() {
        let item = SequenceItem()
        
        #expect(item.elements(from: 0, count: 10).isEmpty)
        #expect(item.elements(page: 0, pageSize: 10).isEmpty)
        #expect(item.first().isEmpty)
        #expect(item.next(after: Tag(group: 0x0010, element: 0x0010)).isEmpty)
        #expect(item.pageCount(pageSize: 10) == 0)
    }
    
    // MARK: - Test Helpers
    
    /// Creates test data elements with sequential tags
    private func createTestElements(count: Int) -> [DataElement] {
        return (0..<count).map { index in
            let group = UInt16(0x0008)
            let element = UInt16(0x0100 + index)
            return DataElement(
                tag: Tag(group: group, element: element),
                vr: .LO,
                length: 4,
                valueData: "TEST".data(using: .utf8)!
            )
        }
    }
}
