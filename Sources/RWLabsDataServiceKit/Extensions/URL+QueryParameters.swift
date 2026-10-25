//
//  URL+QueryParameters.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

public extension URL {
    /// Query items as a dictionary; for repeated names the last value wins
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    }
}
