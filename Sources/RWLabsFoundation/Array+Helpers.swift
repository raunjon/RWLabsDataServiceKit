//
//  Array+Helpers.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public extension Array {
    /// Splits the array into consecutive chunks of `size` (the last may be shorter)
    func chunked(into size: Int) -> [[Element]] {
        precondition(size > 0, "chunked(into:) requires a positive size, got \(size)")
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    mutating func move(from oldIndex: Index, to newIndex: Index) {
        if oldIndex == newIndex { return }
        if abs(newIndex - oldIndex) == 1 { return self.swapAt(oldIndex, newIndex) }
        self.insert(self.remove(at: oldIndex), at: newIndex)
    }
}

public extension Array where Element: Equatable {
    mutating func move(_ element: Element, to newIndex: Index) {
        if let oldIndex = self.firstIndex(of: element) { self.move(from: oldIndex, to: newIndex) }
    }
}
