//
//  LoadableValues+map.swift
//  SSM
//
//  Created by John Demirci on 7/20/25.
//

import Foundation

public extension LoadableValue {
    /// Transforms the loaded value using the provided transform function.
    ///
    /// This method applies a transformation to the loaded value if the state is `.loaded`,
    /// while preserving the original timestamp and leaving all other states unchanged.
    /// This enables functional-style transformations of the success value without
    /// affecting the loading state semantics.
    ///
    /// - Parameter transform: A closure that takes the loaded value and returns a transformed value.
    ///   The transform function should be pure (no side effects) for predictable behavior.
    ///
    /// - Returns: A new `LoadableValue` with the transformed value if the original state was `.loaded`,
    ///   otherwise returns the original `LoadableValue` unchanged.
    ///
    /// - Note: The timestamp from the original `LoadingSuccess` is preserved in the transformed result.
    ///
    /// Example usage:
    /// ```swift
    /// let userProfile: LoadableValue<UserProfile, NetworkError> = .loaded(
    ///     LoadingSuccess(value: UserProfile(name: "John"), timestamp: Date())
    /// )
    ///
    /// let userName: LoadableValue<String, NetworkError> = userProfile.map { profile in
    ///     return profile.name
    /// }
    ///
    /// // Chain multiple transformations
    /// let uppercaseName = userProfile
    ///     .map(\.name)
    ///     .map { $0.uppercased() }
    /// ```
    @inlinable
    func map<NewValue: Sendable>(_ transform: (Value) -> NewValue) -> LoadableValue<NewValue, Failure> {
        switch self {
        case let .loaded(success):
            let transformedValue = transform(success.value)
            let newSuccess = LoadingSuccess(value: transformedValue, timestamp: success.timestamp)
            return .loaded(newSuccess)
        case let .failed(failure):
            return .failed(failure)
        case let .cancelled(date):
            return .cancelled(date)
        case .loading:
            return .loading
        case .idle:
            return .idle
        }
    }
}
