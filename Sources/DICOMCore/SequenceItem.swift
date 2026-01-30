import Foundation

/// DICOM Sequence Item
///
/// Represents a single item within a DICOM Sequence (SQ) data element.
/// Each sequence item contains a collection of data elements and is delimited
/// by Item tags (FFFE,E000) and Item Delimitation Item tags (FFFE,E00D).
///
/// Reference: DICOM PS3.5 Section 7.5 - Nesting of Data Sets
public struct SequenceItem: Sendable {
    /// Data elements contained within this sequence item
    public let elements: [Tag: DataElement]
    
    /// Creates an empty sequence item
    public init() {
        self.elements = [:]
    }
    
    /// Creates a sequence item with the given elements
    /// - Parameter elements: Dictionary of tag to data element mappings
    public init(elements: [Tag: DataElement]) {
        self.elements = elements
    }
    
    /// Creates a sequence item from an array of data elements
    /// - Parameter elements: Array of data elements
    public init(elements: [DataElement]) {
        self.elements = Dictionary(uniqueKeysWithValues: elements.map { ($0.tag, $0) })
    }
    
    /// Accesses a data element by tag
    /// - Parameter tag: The tag to look up
    /// - Returns: The data element if found, nil otherwise
    public subscript(tag: Tag) -> DataElement? {
        return elements[tag]
    }
    
    /// Returns the string value for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: String value or nil
    public func string(for tag: Tag) -> String? {
        return elements[tag]?.stringValue
    }
    
    /// Returns the string values for a given tag, if available
    /// - Parameter tag: The tag to retrieve
    /// - Returns: Array of string values or nil
    public func strings(for tag: Tag) -> [String]? {
        return elements[tag]?.stringValues
    }
    
    /// Number of elements in this sequence item
    public var count: Int {
        return elements.count
    }
    
    /// All tags in this sequence item, sorted
    public var tags: [Tag] {
        return Array(elements.keys).sorted()
    }
    
    /// All data elements in tag order
    public var allElements: [DataElement] {
        return tags.compactMap { elements[$0] }
    }
    
    // MARK: - Pagination Support
    
    /// Returns a specified number of elements starting from an offset
    ///
    /// Retrieves elements in tag-sorted order, useful for paginating through
    /// sequence item data. Elements are sorted by their DICOM tag values.
    ///
    /// - Parameters:
    ///   - startIndex: The zero-based index to start from
    ///   - count: Maximum number of elements to return
    /// - Returns: Array of data elements, may be fewer than count if near end of item
    public func elements(from startIndex: Int, count: Int) -> [DataElement] {
        guard startIndex >= 0, count > 0 else {
            return []
        }
        
        let sortedElements = allElements
        let endIndex = Swift.min(startIndex + count, sortedElements.count)
        
        guard startIndex < sortedElements.count else {
            return []
        }
        
        return Array(sortedElements[startIndex..<endIndex])
    }
    
    /// Returns elements for a specific page with a given page size
    ///
    /// Provides page-based access to data elements sorted by tag order.
    /// Page numbering starts at 0.
    ///
    /// - Parameters:
    ///   - page: Zero-based page number
    ///   - pageSize: Number of elements per page
    /// - Returns: Array of data elements for the requested page
    public func elements(page: Int, pageSize: Int) -> [DataElement] {
        guard page >= 0, pageSize > 0 else {
            return []
        }
        
        let startIndex = page * pageSize
        return elements(from: startIndex, count: pageSize)
    }
    
    /// Returns the next batch of elements starting from a given tag
    ///
    /// Retrieves up to the specified number of elements that come after the given tag
    /// in the standard DICOM tag ordering.
    ///
    /// - Parameters:
    ///   - tag: The tag to start after (exclusive)
    ///   - count: Maximum number of elements to return (default: 10)
    /// - Returns: Array of data elements following the specified tag
    public func next(_ count: Int = 10, after tag: Tag) -> [DataElement] {
        guard count > 0 else {
            return []
        }
        
        let sortedElements = allElements
        
        // Find the index of the element after the given tag
        guard let startIndex = sortedElements.firstIndex(where: { $0.tag > tag }) else {
            return []
        }
        
        let endIndex = Swift.min(startIndex + count, sortedElements.count)
        return Array(sortedElements[startIndex..<endIndex])
    }
    
    /// Returns the first batch of elements from the sequence item
    ///
    /// Convenience method to get the first N elements in tag order.
    ///
    /// - Parameter count: Maximum number of elements to return (default: 10)
    /// - Returns: Array of the first data elements
    public func first(_ count: Int = 10) -> [DataElement] {
        return elements(from: 0, count: count)
    }
    
    /// Returns the total number of pages for a given page size
    ///
    /// - Parameter pageSize: Number of elements per page
    /// - Returns: Total number of pages needed to display all elements
    public func pageCount(pageSize: Int) -> Int {
        guard pageSize > 0 else {
            return 0
        }
        return (count + pageSize - 1) / pageSize
    }
}

// MARK: - Sequence Delimiter Tags
extension Tag {
    /// Item tag (FFFE,E000)
    ///
    /// Marks the beginning of a sequence item.
    /// Reference: PS3.5 Section 7.5.1
    public static let item = Tag(group: 0xFFFE, element: 0xE000)
    
    /// Item Delimitation Item tag (FFFE,E00D)
    ///
    /// Marks the end of a sequence item with undefined length.
    /// Reference: PS3.5 Section 7.5.1
    public static let itemDelimitationItem = Tag(group: 0xFFFE, element: 0xE00D)
    
    /// Sequence Delimitation Item tag (FFFE,E0DD)
    ///
    /// Marks the end of a sequence with undefined length.
    /// Reference: PS3.5 Section 7.5.1
    public static let sequenceDelimitationItem = Tag(group: 0xFFFE, element: 0xE0DD)
}
