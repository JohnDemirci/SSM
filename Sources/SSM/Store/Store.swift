import Combine
import Foundation
import LoadableValues
import SwiftUI

/// A generic, observable, main-actor-isolated store for managing application state, handling requests via a reducer, and integrating with an environment.
///
/// `Store` is the core type for feature-oriented state management. It holds the current state, supports dynamic member access to state properties, and coordinates all mutations through a reducer conforming to `Reducer`.
///
/// - Generic Parameter `R`: The reducer type, which must conform to `Reducer`.
///
/// ## Responsibilities
/// - Maintains the current feature state, exposing it for reading and mutation.
/// - Executes requests by delegating to the reducer's `reduce(store:request:)` methods, supporting both async and sync dispatch.
/// - Integrates with a feature-specific environment, available to all operations and async tasks.
/// - Tracks and manages active async tasks, enabling cancellation and proper resource cleanup.
/// - Listens for broadcast messages (e.g., global app events) and forwards them to the reducer.
/// - Offers convenient helpers for loading, transforming, and modifying state, especially for `LoadableValue` asynchronous operations.
///
/// ## Usage
/// - Initialize with an initial state and environment.
/// - Use `send(_:)` to dispatch requests (actions) to the reducer.
/// - Use dynamic member lookup to easily access state properties: `store.someProperty`.
/// - Use provided async helpers for loading and transforming state with environment dependencies.
///
/// ## Threading
/// - All state mutations and reads occur on the main actor.
/// - All async work is tracked, cancellable, and reentrant-safe.
///
/// ## Example
/// ```swift
/// let store = Store<MyFeatureReducer>(initialState: ..., environment: ...)
/// await store.send(.loadData)
/// store.cancelActiveTask(for: \.someLoadableValue)
/// let value = store.someStateProperty
/// ```
///
/// ## See Also
/// - ``Reducer``
/// - ``StoreProtocol``
/// - ``LoadableValue``
@MainActor
@dynamicMemberLookup
@Observable
public final class Store<R: Reducer>: @preconcurrency StoreProtocol, Sendable, Identifiable {
    public typealias State = R.State
    public typealias Request = R.Request
    public typealias Environment = R.Environment

    internal let environment: Environment
    internal let reducer: R

    @ObservationIgnored
	nonisolated(unsafe)
    internal var activeTasks: [String: Task<Void, Never>] = [:]

    @ObservationIgnored
    nonisolated(unsafe)
    private var broadcastTask: Task<Void, Never>?

    /// The current feature state held by the store.
    ///
    /// This property represents the source of truth for all state managed by the store. It is observed for changes and exposed via dynamic member lookup,
    /// allowing UI and other consumers to react to updates. All mutations to `state` must occur via reducer operations or on the main actor to maintain consistency
    /// and thread safety.
    ///
    /// - Important: For best practices, treat `state` as read-only outside of the reducer or store methods. Direct mutation is discouraged except from within the reducer logic.
    /// - Note: When using SwiftUI, views observing the store will automatically refresh when `state` changes.
    internal(set) public var state: State

    #if DEBUG
    internal(set) public var valueChanges: [ValueChange<R>] = []
    #endif

    /// A unique reference identifier for the store instance.
    ///
    /// The `id` property is used to uniquely identify a store, making it suitable for differentiating between multiple store instances,
    /// especially when managing collections of stores or when referencing child/parent relationships within a feature hierarchy.
    ///
    /// - Note: When the store’s state conforms to `Identifiable`, this identifier will be derived from the state’s own `id` property.
    ///         Otherwise, it is constructed from the type of the store.
    public let id: ReferenceIdentifier

    init(
        initialState: State,
        id: ReferenceIdentifier,
        environment: Environment
    ) {
        self.state = initialState
        self.environment = environment
        self.id = id
        self.reducer = .init()

        self.broadcastTask = Task { [weak self] in
            guard let self else { return }
            for await message in BroadcastStudio.shared.channel {
                await self.reducer.didReceiveBroadcastMessage(message, in: self)
            }
        }
    }

    deinit {
        broadcastTask?.cancel()
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    @inlinable
    public subscript<S>(dynamicMember keyPath: KeyPath<State, S>) -> S {
        state[keyPath: keyPath]
    }

    /// Dispatches a request to the reducer for asynchronous handling, awaiting its completion.
    ///
    /// This method schedules the provided request (action) to be processed by the reducer on the main actor. It suspends execution until the reducer has finished handling the request, allowing callers to await any side effects, loading, or state mutations that result from handling the action.
    ///
    /// Use this method when you need to ensure that the reducer has fully processed the request before continuing, such as when chaining async operations or updating UI based on the outcome.
    ///
    /// - Parameter request: The request (action) to be handled by the reducer.
    ///
    /// - Note: If you do not require awaiting the completion of the reducer's async work, consider using the synchronous `send(_:)` overload, which schedules the request in a fire-and-forget manner.
    ///
    /// Typical usage:
    /// ```
    /// await store.send(.loadData)
    /// ```
    public func send(_ request: sending Request) async {
        await reducer.reduce(store: self, request: request)
    }

    /// Dispatches a request to the reducer for synchronous handling.
    ///
    /// This method schedules the provided request (action) to be processed by the reducer on the main actor. The request will be handled in an asynchronous context, but the method itself returns immediately without awaiting completion. This is useful for UI-driven or fire-and-forget operations where you do not require a result or need to await the outcome.
    ///
    /// - Parameter request: The request (action) to be handled by the reducer.
    ///
    /// - Note: If you need to await the completion of an asynchronous reducer operation or require a result, use the async version of `send(_:)`.
    ///
    /// Typical usage:
    /// ```
    /// store.send(.increment)
    /// ```
    public func send(_ request: Request) {
        Task { @MainActor in await reducer.reduce(store: self, request: request) }
    }
}

public extension Store {
    /// Cancels the active asynchronous task associated with a specific `LoadableValue` in the state.
    ///
    /// This method locates and cancels the running async task responsible for loading or updating the value at the provided key path.
    /// After cancellation, the corresponding state property is updated to `.cancelled`, reflecting that the operation was interrupted.
    ///
    /// - Parameter keyPath: A writable key path to a `LoadableValue` property in the store's state, representing the value whose associated task should be cancelled.
    ///
    /// - Important: If there is no active task for the given key path, this method does nothing.
    ///
    /// - Note: The state update to `.cancelled` is performed on the main actor to ensure thread safety.
    ///
    /// Typical usage:
    /// ```
    /// store.cancelActiveTask(for: \.someLoadableProperty)
    /// ```
    func cancelActiveTask<V>(
        for keyPath: WritableKeyPath<State, LoadableValue<V, Error>>
    ) {
        let taskKey = String(describing: keyPath)
        if let task = activeTasks[taskKey] {
            task.cancel()
            activeTasks.removeValue(forKey: taskKey)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.set(keyPath: keyPath, .cancelled(.now))
            }
        }
    }

    /// Cancels the active asynchronous task associated with a specific `LoadableValue` entry in a dictionary within the state.
    ///
    /// This method locates and cancels the running async task responsible for loading or updating the value at the provided key in the dictionary at the specified key path.
    /// After cancellation, the corresponding dictionary entry in the state is updated to `.cancelled`, reflecting that the operation was interrupted.
    ///
    /// - Parameters:
    ///   - keyPath: A writable key path to a dictionary property in the store's state, where each value is a `LoadableValue`.
    ///   - key: The key in the dictionary whose associated async task should be cancelled.
    ///
    /// - Important: If there is no active task for the given key path and key, this method does nothing.
    ///
    /// - Note: The state update to `.cancelled` is performed on the main actor to ensure thread safety.
    ///
    /// Typical usage:
    /// ```
    /// store.cancelActiveTask(for: \.someDictionaryProperty, key: someKey)
    /// ```
    func cancelActiveTask<V, K: Hashable & Sendable>(
        for keyPath: WritableKeyPath<State, [K: LoadableValue<V, Error>]>,
        key: K
    ) {
        let taskKey = String(describing: keyPath) + String(describing: key)
        if let task = activeTasks[taskKey] {
            task.cancel()
            activeTasks.removeValue(forKey: taskKey)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.set(keyPath: keyPath, key: key, value: .cancelled(.now))
            }
        }
    }

    /// Cancels the active asynchronous task associated with a specific property in the store's state.
    ///
    /// This method locates and cancels the running async task responsible for loading or updating the value at the provided key path.
    /// After cancellation, the task is removed from the store's internal registry of active tasks.
    ///
    /// - Parameter keyPath: A writable key path to any property in the store's state whose associated asynchronous task should be cancelled.
    ///
    /// - Important: If there is no active task for the given key path, this method does nothing.
    ///
    /// - Note: The state at the provided key path is not automatically updated; only the running task is cancelled and deregistered.
    ///
    /// Typical usage:
    /// ```
    /// store.cancelActiveTask(for: \.someStateProperty)
    /// ```
    func cancelActiveTask<T>(
        for keyPath: WritableKeyPath<State, T>
    ) {
        let taskKey = String(describing: keyPath)
        if let task = activeTasks[taskKey] {
            task.cancel()
            activeTasks.removeValue(forKey: taskKey)
        }
    }
}

public extension Store where State: Identifiable {
    /// Creates a new store with the provided initial state and environment, deriving the store's unique identity from the state's identifier.
    ///
    /// This initializer should be used when your state type conforms to `Identifiable`. The store's identity will be based on the state's `id` value, ensuring uniqueness and safe referencing in parent/child or collection scenarios.
    ///
    /// - Parameters:
    ///   - initialState: The initial state for the store. Must conform to `Identifiable`.
    ///   - environment: The environment object providing dependencies such as services, clients, or configuration needed by the reducer.
    ///
    /// The store’s unique identifier will be constructed using the `id` property from the given state instance.
    ///
    /// Typical usage:
    /// ```
    /// let store = Store(initialState: MyState(id: ...), environment: MyEnvironment())
    /// ```
    convenience init(
        initialState: State,
        environment: Environment,
    ) {
        self.init(
            initialState: initialState,
            id: ReferenceIdentifier(id: initialState.id as AnyHashable),
            environment: environment
        )
    }
}

public extension Store {
    /// Creates a new store with the provided initial state and environment.
    ///
    /// This initializer is suitable for most features whose state does not conform to `Identifiable`, or where a unique store identity is not otherwise required.
    ///
    /// - Parameters:
    ///   - initialState: The initial state for the store, used to initialize the feature’s state container.
    ///   - environment: The environment value to be associated with this store, providing any external dependencies (such as services or clients) needed by the reducer.
    ///
    /// The store’s unique identity will be derived from the type of the store itself.
    ///
    /// Typical usage:
    /// ```
    /// let store = Store(initialState: MyState(), environment: MyEnvironment())
    /// ```
    convenience init(
        initialState: State,
        environment: Environment,
    ) {
        self.init(
            initialState: initialState,
            id: ReferenceIdentifier(id: ObjectIdentifier(Self.self) as AnyHashable),
            environment: environment
        )
    }
}
