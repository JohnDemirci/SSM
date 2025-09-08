//
//  StoreDebugContext.swift
//  SSM
//
//  Created by John Demirci on 7/30/25.
//

#if DEBUG
import Foundation
import LoadableValues

@MainActor
public struct StoreDebugContext<R: Reducer> {
    let store: Store<R>

    internal init(store: Store<R>) {
        self.store = store
    }
}

extension Store {
    /// Returns a debug context for the store, enabling direct manipulation of state and broadcasting of messages for debugging purposes.
    ///
    /// Use the returned `StoreDebugContext` to perform mutations or simulate broadcasts without affecting normal reducer flow.
    /// This method is intended only for debugging or testing environments and should not be used in production code.
    ///
    /// - Returns: A `StoreDebugContext` instance associated with this store, allowing for debug-specific interactions.
    public func debugContext() -> StoreDebugContext<R> {
        return StoreDebugContext(store: self)
    }
}

extension StoreDebugContext {
    /// Allows direct modification of the store's state for debugging purposes.
    ///
    /// This method provides an inout reference to the store's state, enabling you to mutate its values in a closure.
    /// Use this during testing or debugging to simulate state changes without triggering normal reducer logic or actions.
    ///
    /// - Parameter completion: A closure that receives an inout reference to the store's current state for mutation.
    /// - Returns: The current `StoreDebugContext` instance, allowing for method chaining.
    ///
    /// - Note: This method should only be used in debugging or testing environments.
    @discardableResult
    public func modifyValues(
        completion: @escaping (inout Store<R>.State) -> Void
    ) -> StoreDebugContext<R> {
        completion(&store.state)
        return self
    }

    /// Broadcasts a message to all subscribers in the application's broadcast system for debugging or testing purposes.
    ///
    /// Use this method to simulate the sending of a broadcast message to all stores. Each store will invoke its reducer's
    /// `didReceiveBroadcastMessage` method, allowing you to observe and test how your application's state responds to
    /// broadcast events.
    ///
    /// - Parameter message: A message conforming to `BroadcastMessage` that will be published to all subscribers.
    /// - Returns: The current `StoreDebugContext` instance, enabling method chaining for additional debug actions.
    ///
    /// - Note: This method is synchronous and is intended for use only in debugging or testing environments.
    ///   To simulate a broadcast to a single store only, prefer using `selfOnlyBroadcast(_:)`.
    ///   This method does not trigger normal reducer logic for actions, but directly invokes broadcast handling paths.
    @discardableResult
    public func broadcast<M: BroadcastMessage>(
        _ message: M
    ) async -> StoreDebugContext<R> {
        // TODO: - handle
        return self
    }

    /// Simulates the receipt of a broadcast message by this store only, bypassing the global broadcast system.
    ///
    /// Use this method to directly invoke the reducer's `didReceiveBroadcastMessage(_:in:)` for the associated store,
    /// without notifying any other stores in the application. This is useful for testing or debugging how a single store
    /// responds to broadcast messages, without triggering side effects elsewhere.
    ///
    /// - Parameter message: A message conforming to `BroadcastMessage` to be delivered to the store.
    /// - Returns: The current `StoreDebugContext` instance, allowing for method chaining.
    ///
    /// - Note: This method is asynchronous and does not trigger normal reducer logic for actions, but instead
    ///   directly invokes the store's broadcast message handling path.
    @discardableResult
    public func selfOnlyBroadcast<M: BroadcastMessage>(
        _ message: M
    ) async -> StoreDebugContext<R> {
        // TODO: - handle
        return self
    }
}

#endif
