//
//  LoadingSuccess.swift
//  SSM
//
//  Created by John Demirci on 6/21/25.
//

import Foundation

/// A structure that represents a successful loading operation with a timestamp.
///
/// `LoadingSuccess` encapsulates a successfully loaded value along with the timestamp
/// of when the loading operation completed. This is used within `LoadableValue` to
/// track both the data and when it was loaded.
///
/// - Generic Parameters:
///   - `Value`: The type of the successfully loaded value.
///
/// Example usage:
/// ```swift
/// let success = LoadingSuccess(value: "Hello, World!", timestamp: Date())
/// let loadableValue: LoadableValue<String, Error> = .loaded(success)
/// ```
public struct LoadingSuccess<Value> {
    /// The successfully loaded value.
    public let value: Value
    
    /// The timestamp when the loading operation completed successfully.
    public let timestamp: Date

    /// Creates a new `LoadingSuccess` instance with the specified value and timestamp.
    ///
    /// - Parameters:
    ///   - value: The successfully loaded value.
    ///   - timestamp: The timestamp when the loading operation completed.
    public init(value: Value, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
}

extension LoadingSuccess: Equatable where Value: Equatable {}
extension LoadingSuccess: Hashable where Value: Hashable {}
extension LoadingSuccess: Decodable where Value: Decodable {}
extension LoadingSuccess: Encodable where Value: Encodable {}
extension LoadingSuccess: Sendable where Value: Sendable {}
