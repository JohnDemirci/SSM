import Foundation

/// A protocol that defines the requirements for a type representing a stateful, reference-based store.
///
/// `StoreProtocol` is intended to serve as the interface for objects that manage an internal state
/// and handle requests, potentially mutating state or triggering side effects. Stores conforming to
/// this protocol are reference types.
///
/// - Note: Conforming types must be classes (`AnyObject`).  
///
/// ## Associated Types
/// - `State`: The type representing the current state managed by the store.
/// - `Request`: The type of requests that can be sent to the store for processing.
/// - `Environment`: A `Sendable` type that provides dependencies or context required by the store.
///
/// ## Properties
/// - `state`: The current value representing the store's state.
/// - `id`: A unique identifier for the store instance.
///
/// ## Methods
/// - `send(_:) async`: Sends a request to the store asynchronously. Use this method when request handling may be asynchronous.
/// - `send(_:)`: Sends a request to the store synchronously. Use this method for immediate, synchronous request handling.
///
/// ## Parameters
/// - `request`: The request to be handled by the store, sent in a way that allows for transfer or mutation semantics.
///
/// ## Usage
/// Stores are typically used to encapsulate business logic, state, and side-effects, and can be composed or observed as needed.
public protocol StoreProtocol: AnyObject, Sendable, Equatable {
    associatedtype State
    associatedtype Request
    associatedtype Environment: Sendable

    var state: State { get }
    var id: ReferenceIdentifier { get }
    func send(_ request: sending Request) async
    func send(_ request: sending Request)
}

extension StoreProtocol {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
