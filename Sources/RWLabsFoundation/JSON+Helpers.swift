//
//  JSON+Helpers.swift
//  RWLabsFoundation
//
//  Created by RWLabs
//

import Foundation

public extension Data {
    func toDict() -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: self, options: [.fragmentsAllowed])) as? [String: Any]
    }

    func toPrettyPrintedJSONString() -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: [.fragmentsAllowed]),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .fragmentsAllowed]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

public extension Encodable {
    /// Encodes with `encoder`. Pass your API configuration's encoder to get the
    /// same keys and dates the API uses.
    func toData(encoder: JSONEncoder = JSONEncoder()) -> Data? {
        try? encoder.encode(self)
    }

    func toDict(encoder: JSONEncoder = JSONEncoder()) -> [String: Any]? {
        toData(encoder: encoder)?.toDict()
    }

    func toPrettyPrintedJSONString(encoder: JSONEncoder = JSONEncoder()) -> String? {
        toData(encoder: encoder)?.toPrettyPrintedJSONString()
    }
}

public extension Dictionary {
    /// JSON data, or `nil` if the dictionary holds values JSON can't represent
    /// (checked up front: `JSONSerialization` would otherwise raise an uncatchable exception)
    func toData() -> Data? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        return try? JSONSerialization.data(withJSONObject: self)
    }
}
