//
//  BaseItem.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// Convenience for codable models shown in collections
///
/// Equality and hashing are the compiler-synthesized ones over all stored
/// properties, so two versions of the same item with different content are
/// not equal and list diffing picks up the change.
public protocol BaseItem: Codable, Identifiable, Hashable {}
