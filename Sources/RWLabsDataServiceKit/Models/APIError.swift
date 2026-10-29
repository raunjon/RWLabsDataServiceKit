//
//  APIError.swift
//  RWLabsDataServiceKit
//
//  Created by RWLabsDataServiceKit
//

import Foundation

/// The body of a non-2xx response, available as `NetworkError.apiError`
///
/// Decoding is lenient so one unexpected field never discards the rest. Accepted shapes:
/// ```json
/// {"message": "Not found", "status": "404", "error": {"status": 404, "message": "No such user"}}
/// {"error": "Invalid token"}
/// {"status": 422, "code": "validation_failed", "errors": {"email": ["is invalid"]}}
/// {"errors": ["Something went wrong"]}
/// ```
public struct APIError: Decodable, Sendable, Equatable, Error {
    /// Human-readable message: top-level `message`, else `error.message`, else `error` when it is a string
    public var message: String?

    /// `status` from the top level or inside `error`, sent as a number or a string
    public var status: Int?

    /// Machine-readable `code` from the top level or inside `error`
    public var code: String?

    /// Validation errors from `errors`, keyed by field
    ///
    /// A plain list (`["Something went wrong"]`) is stored under `"base"`.
    /// Field names go through the decoder's key strategy, so with
    /// `.convertFromSnakeCase` `first_name` arrives as `firstName`.
    public var fieldErrors: [String: [String]]

    public init(message: String? = nil, status: Int? = nil, code: String? = nil, fieldErrors: [String: [String]] = [:]) {
        self.message = message
        self.status = status
        self.code = code
        self.fieldErrors = fieldErrors
    }

    /// Whether the body carried none of the recognised fields
    public var isEmpty: Bool {
        message == nil && status == nil && code == nil && fieldErrors.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case message, status, code, error, errors
    }

    private struct Detail: Decodable {
        var message: String?
        var status: Int?
        var code: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            message = container.lenientString(forKey: .message)
            status = container.lenientInt(forKey: .status)
            code = container.lenientString(forKey: .code)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let detail = try? container.decode(Detail.self, forKey: .error)

        message = container.lenientString(forKey: .message)
            ?? detail?.message
            ?? (try? container.decode(String.self, forKey: .error))
        status = container.lenientInt(forKey: .status) ?? detail?.status
        code = container.lenientString(forKey: .code) ?? detail?.code

        // A keyed container (not [String: _]) so field names get the decoder's key
        // strategy on every OS release; dictionary keys are treated inconsistently.
        if let errors = try? container.nestedContainer(keyedBy: FieldKey.self, forKey: .errors) {
            var fields: [String: [String]] = [:]
            for key in errors.allKeys {
                if let messages = try? errors.decode([String].self, forKey: key) {
                    fields[key.stringValue] = messages
                } else if let message = try? errors.decode(String.self, forKey: key) {
                    fields[key.stringValue] = [message]
                }
            }
            fieldErrors = fields
        } else if let errors = try? container.decode([String].self, forKey: .errors), !errors.isEmpty {
            fieldErrors = ["base": errors]
        } else {
            fieldErrors = [:]
        }
    }

    private struct FieldKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }
}

private extension KeyedDecodingContainer {
    /// A string, or a number rendered as a string; `nil` for anything else
    func lenientString(forKey key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        return nil
    }

    /// A number, or a string holding a number; `nil` for anything else
    func lenientInt(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(String.self, forKey: key) { return Int(value) }
        return nil
    }
}
