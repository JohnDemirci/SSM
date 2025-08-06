//
//  LoadingFailure.swift
//  SSM
//
//  Created by John Demirci on 6/21/25.
//

import Foundation

/// A structure that represents a failed loading operation with a timestamp.
///
/// `LoadingFailure` encapsulates a failed loading operation along with the timestamp
/// of when the failure occurred. This is used within `LoadableValue` to track both
/// the error and when it happened.
///
/// - Generic Parameters:
///   - `Failure`: The type of error that occurred during loading. Must conform to `Error`.
///
/// Example usage:
/// ```swift
/// let failure = LoadingFailure(failure: NetworkError.timeout, timestamp: Date())
/// let loadableValue: LoadableValue<String, NetworkError> = .failed(failure)
/// ```
public struct LoadingFailure<Failure: Error> {
    /// The error that occurred during the loading operation.
    public let failure: Failure

    /// The timestamp when the loading operation failed.
    public let timestamp: Date

    /// Creates a new `LoadingFailure` instance with the specified error and timestamp.
    ///
    /// - Parameters:
    ///   - failure: The error that occurred during loading.
    ///   - timestamp: The timestamp when the loading operation failed.
    public init(failure: Failure, timestamp: Date) {
        self.failure = failure
        self.timestamp = timestamp
    }
}

extension LoadingFailure: Equatable {
    /// Compares two `LoadingFailure` instances for equality.
    ///
    /// Two `LoadingFailure` instances are considered equal if they have the same
    /// localized description for their failures and the same timestamp.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `LoadingFailure` instance.
    ///   - rhs: The right-hand side `LoadingFailure` instance.
    /// - Returns: `true` if the instances are equal, otherwise `false`.
    public static func == (lhs: LoadingFailure, rhs: LoadingFailure) -> Bool {
        lhs.failure.localizedDescription == rhs.failure.localizedDescription &&
            lhs.timestamp == rhs.timestamp
    }
}

extension LoadingFailure: Hashable {
    /// Hashes the essential components of the `LoadingFailure` instance.
    ///
    /// The hash is computed using the failure's localized description and timestamp.
    ///
    /// - Parameter hasher: The hasher to use for combining the components.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(failure.localizedDescription)
        hasher.combine(timestamp)
    }
}

extension LoadingFailure: Encodable where Failure: Encodable {}
extension LoadingFailure: Decodable where Failure: Decodable {}
extension LoadingFailure: Sendable where Failure: Sendable {}
