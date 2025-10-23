//
//  LoadableValues.swift
//  SSM
//
//  Created by John Demirci on 6/21/25.
//

import Foundation
import OSLog
import os

/// A type that represents the state of an asynchronous loading operation.
///
/// `LoadableValue` is a generic enum that encapsulates the different states that an asynchronous
/// operation can be in, along with associated data for each state. This is particularly useful
/// for managing UI states in applications that load data asynchronously.
///
/// - Generic Parameters:
///   - `Value`: The type of the successfully loaded value. Must conform to `Sendable`.
///   - `Failure`: The type of error that can occur during loading. Must conform to `Error`.
///
/// - States:
///   - `idle`: The initial state before any loading operation begins
///   - `loading`: The operation is currently in progress
///   - `loaded`: The operation completed successfully with a value
///   - `failed`: The operation failed with an error
///   - `cancelled`: The operation was cancelled at a specific time
///
/// Example usage:
/// ```swift
/// var userProfile: LoadableValue<UserProfile, NetworkError> = .idle
///
/// // Start loading
/// userProfile = .loading
///
/// // Handle success
/// userProfile = .loaded(LoadingSuccess(value: profile, timestamp: Date()))
///
/// // Handle failure
/// userProfile = .failed(LoadingFailure(failure: error, timestamp: Date()))
/// ```
public enum LoadableValue<Value: Sendable, Failure: Error>: Sendable {
    case cancelled(Date)
    case failed(LoadingFailure<Failure>)
    case loaded(LoadingSuccess<Value>)
    case loading
    case idle
}

extension LoadableValue: Equatable where Value: Equatable {
    public static func == (lhs: LoadableValue<Value, Failure>, rhs: LoadableValue<Value, Failure>) -> Bool {
        switch (lhs, rhs) {
        case let (.cancelled(lhsDate), .cancelled(rhsDate)):
            return lhsDate == rhsDate
        case let (.failed(lhsError), .failed(rhsError)):
            return lhsError == rhsError
        case let (.loaded(lhsSuccess), .loaded(rhsSuccess)):
            return lhsSuccess == rhsSuccess
        case (.loading, .loading), (.idle, .idle):
            return true
        default:
            return false
        }
    }
}

extension LoadableValue: Hashable where Value: Hashable, Failure: Hashable {}
extension LoadableValue: Encodable where Value: Encodable, Failure: Encodable {}
extension LoadableValue: Decodable where Value: Decodable, Failure: Decodable {}

public extension LoadableValue {
    /// Returns the loaded value if the state is `.loaded`, otherwise returns `nil`.
    ///
    /// This computed property provides a convenient way to extract the successful value
    /// from a `LoadableValue` without having to pattern match on the enum cases.
    ///
    /// - Returns: The loaded value if available, otherwise `nil`.
    @inlinable
    var value: Value? {
        guard case let .loaded(success) = self else { return nil }
        return success.value
    }

    /// Returns the failure error if the state is `.failed`, otherwise returns `nil`.
    ///
    /// This computed property provides a convenient way to extract the error
    /// from a failed `LoadableValue` without having to pattern match on the enum cases.
    ///
    /// - Returns: The error if the state is failed, otherwise `nil`.
    @inlinable
    var failure: Error? {
        guard case let .failed(error) = self else { return nil }
        return error.failure
    }

    @inlinable
    var isFailure: Bool {
        self.failure != nil
    }
}

public extension LoadableValue {
    /// Modifies the loaded value in place if the state is `.loaded`.
    ///
    /// This method allows you to transform the loaded value while preserving the original
    /// timestamp. If the current state is not `.loaded`, this method will either trigger
    /// an assertion failure (in debug builds) or log an error (in release builds).
    ///
    /// - Parameter transform: A closure that takes an inout parameter of the loaded value type
    ///   and modifies it in place.
    ///
    /// - Warning: This method should only be called when the state is `.loaded`. Calling it
    ///   on other states will result in a runtime error in debug builds or a logged error
    ///   in release builds.
    ///
    /// Example usage:
    /// ```swift
    /// var loadedData: LoadableValue<[String], Error> = .loaded(LoadingSuccess(value: ["item1"], timestamp: Date()))
    /// loadedData.modify { items in
    ///     items.append("item2")
    /// }
    /// ```
    @inlinable
    mutating func modify(transform: (inout Value) -> Void) {
        switch self {
        case let .loaded(success):
            var value = success.value
            transform(&value)
            self = .loaded(LoadingSuccess(value: value, timestamp: success.timestamp))
        default:
            logger.error("Attempted to modify a non-loaded LoadableValue")
        }
    }
}

public extension LoadableValue {
    /// Returns `true` if the current state is `.loading`, otherwise `false`.
    ///
    /// This method provides a convenient way to check if an asynchronous operation
    /// is currently in progress without having to pattern match on the enum cases.
    ///
    /// - Returns: `true` if the state is `.loading`, otherwise `false`.
    ///
    /// Example usage:
    /// ```swift
    /// let userProfile: LoadableValue<UserProfile, NetworkError> = .loading
    /// if userProfile.isLoading() {
    ///     // Show loading indicator
    /// }
    /// ```
    @inlinable
    func isLoading() -> Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }
}
