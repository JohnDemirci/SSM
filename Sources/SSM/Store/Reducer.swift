//
//  Reducer.swift
//  SSM
//
//  Created by John Demirci on 7/3/25.
//

import Foundation
import LoadableValues

#if canImport(Combine)
import Combine
#endif

/// A protocol that defines the core reducer pattern for state management.
///
/// `Reducer` is the central component of the SSM (State Store Manager) architecture.
/// It defines how state changes in response to requests, providing a predictable
/// and testable way to manage application state.
///
/// The reducer pattern ensures that:
/// - State mutations are centralized and controlled
/// - Business logic is separated from UI concerns
/// - State changes are predictable and testable
/// - Side effects are managed through the environment
///
/// - Associated Types:
///   - `State`: The type representing the application state managed by this reducer
///   - `Request`: The type of actions/requests that can modify the state
///   - `Environment`: The dependencies and services needed by the reducer
///
/// Example implementation:
/// ```swift
/// struct UserProfileReducer: Reducer {
///     struct State {
///         var profile: LoadableValue<UserProfile, Error> = .idle
///         var isEditing: Bool = false
///     }
///
///     enum Request {
///         case loadProfile
///         case toggleEditing
///     }
///
///     struct Environment {
///         let userService: UserService
///     }
///
///     func reduce(store: Store<Self>, request: Request) async {
///         switch request {
///         case .loadProfile:
///             await load(store: store, keyPath: \.profile) { env in
///                 try await env.userService.fetchProfile()
///             }
///         case .toggleEditing:
///             modifyValue(store: store, \.isEditing) { $0.toggle() }
///         }
///     }
/// }
/// ```
@MainActor
public protocol Reducer: Sendable {
    /// The type representing the state managed by this reducer.
    ///
    /// `State` holds all relevant data that describes the current condition
    /// of the feature or domain managed by the reducer. All state mutations
    /// in response to requests or broadcast messages are performed on this type.
    ///
    /// - Note: `State` should be a value type (typically a struct) to ensure
    ///   predictable and testable state management.
    associatedtype State

    /// The type representing the requests or actions that can modify the state.
    ///
    /// `Request` defines all the possible actions, user intents, or events that
    /// this reducer can handle to trigger state transitions or side effects.
    /// Typically modeled as an enum, each case represents a distinct action or
    /// event relevant to the feature or domain managed by the reducer.
    ///
    /// - Note: Defining requests as an enum encourages exhaustiveness and clarity,
    ///   making it easier to reason about all possible state transitions.
    associatedtype Request = Void

    /// The type representing the environment dependencies for this reducer.
    ///
    /// `Environment` encapsulates all external dependencies, services, and clients
    /// required by the reducer to perform its work. This can include API clients,
    /// local data stores, configuration objects, or any other state-independent
    /// collaborators needed by the reducer's logic.
    ///
    /// By grouping dependencies into an `Environment` type, you achieve:
    /// - Decoupling of business logic from concrete implementation details
    /// - Easier testing and mocking of dependencies
    /// - More explicit, testable, and maintainable code
    ///
    /// - Note: `Environment` should conform to `Sendable` to ensure safe usage in
    ///   concurrent contexts and avoid data races.
    associatedtype Environment: Sendable = Void

    /// The main entry point for processing requests and updating state.
    ///
    /// This method is called whenever a request is sent to the store. It should
    /// handle the request and update the state accordingly using the provided
    /// convenience methods.
    ///
    /// - Parameters:
    ///   - store: The store instance that manages the state
    ///   - request: The request to processing
    ///
    /// - Note: Do not call this method directly. Instead, use the store's `send(_:)` method
    /// - Important: do not call the send method directly from this method.
    func reduce<SP: StoreProtocol>(
        store: SP,
        request: Request
    ) async

    /// Sets up subscriptions to asynchronous data sources or external dependencies.
    ///
    /// This method is called during store initialization to allow the reducer
    /// to subscribe to streams, publishers, or other async sources from the environment.
    /// Use this to react to external changes (such as notifications, timers, data updates)
    /// and dispatch requests to update state in response.
    ///
    /// - Parameter store: The store instance managing the state and environment for this reducer.
    ///
    /// - Note: The default implementation does nothing. Override this method to set up
    ///   subscriptions specific to the reducer's logic, such as:
    ///   - Listening to environment publisher/stream events and sending requests
    ///   - Registering observers or Combine subscriptions
    ///   - Scheduling periodic tasks or timers
    ///
    /// Example:
    /// ```swift
    /// func setupSubscriptions(store: Store<Self>) {
    ///     subscribe(store: store, keypath: \.timerService) { timerService in
    ///         timerService.tickPublisher()
    ///     } map: { _ in
    ///         .timerTick
    ///     }
    /// }
    /// ```
    func setupSubscriptions<SP>(store: SP)

    /// Creates a new instance of the reducer.
    ///
    /// The reducer must be initializable without parameters to support
    /// the store's initialization process.
    init()
}

extension Reducer {
    public func setupSubscriptions<SP: StoreProtocol>(store: SP) {}
}

extension Reducer where Request == Void {
    public func reduce<SP: StoreProtocol>(
        store: SP,
        request: Request
    ) async {}
}

public extension Reducer {
    /// Performs asynchronous work and updates the state at the specified key path.
    ///
    /// This method executes the provided work closure with the environment and
    /// updates the state with the result. Use this for operations that don't
    /// involve error handling or loading states.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the state property to update
    ///   - work: The asynchronous work to perform, receiving the environment
    ///
    /// Example usage:
    /// ```swift
    /// await perform(store: store, keyPath: \.timestamp) { env in
    ///     Date()
    /// }
    /// ```
    func perform<T, SP: StoreProtocol>(
        store: SP,
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) async -> sending T
    ) async {
        if isTesting {
            #if DEBUG
            // check if they are using store to unit test
            // performance is not important in this context so we can use as
            
            if let store = store as? Store<Self> {
                // the consumer of this library is using the store instance as test
                await store.performAsync(keyPath: keyPath, work: work)
            } else if let store = store as? TestStore<Self> {
                // intended usecase
                await store.performAsync(keyPath: keyPath, work: work)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            // use unsafe downcast for performance gain
            await unsafeDowncast(store, to: Store<Self>.self)
                .performAsync(keyPath: keyPath, work: work)
        }
    }

    /// Performs asynchronous work with transformation and updates the state.
    ///
    /// This method executes the provided work closure, transforms the result,
    /// and updates the state with the transformed value. Useful when the work
    /// returns a different type than what's stored in state.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the state property to update
    ///   - work: The asynchronous work to perform, receiving the environment
    ///   - transform: A closure that transforms the work result to the state type
    ///
    /// Example usage:
    /// ```swift
    /// await perform(store: store, keyPath: \.userCount, work: { env in
    ///     try await env.userService.fetchUsers()
    /// }, map: { users in
    ///     users.count
    /// })
    /// ```
    func perform<StateValue, ClientValue: Sendable, SP: StoreProtocol>(
        store: SP,
        keyPath: WritableKeyPath<State, StateValue>,
        work: @Sendable @escaping (Environment) async -> ClientValue,
        map transform: @Sendable @escaping (ClientValue) -> StateValue
    ) async {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                await store.performAsync(keyPath: keyPath, work: work, map: transform)
            } else if let store = store as? TestStore<Self> {
                await store.performAsync(keyPath: keyPath, work: work, map: transform)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            await unsafeDowncast(store, to: Store<Self>.self)
                .performAsync(keyPath: keyPath, work: work, map: transform)
        }
    }

    /// Performs synchronous work and updates the state at the specified key path.
    ///
    /// This method executes the provided work closure synchronously with the
    /// environment and updates the state with the result. Use this for quick
    /// operations that don't require async/await.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the state property to update
    ///   - work: The synchronous work to perform, receiving the environment
    ///
    /// Example usage:
    /// ```swift
    /// perform(store: store, keyPath: \.configuration) { env in
    ///     env.configurationProvider.currentConfig
    /// }
    /// ```
    func perform<T, SP: StoreProtocol>(
        store: SP,
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) -> T
    ) {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                store.performSync(keyPath: keyPath, work: work)
            } else if let store = store as? TestStore<Self> {
                store.performSync(keyPath: keyPath, work: work)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            unsafeDowncast(store, to: Store<Self>.self)
                .performSync(keyPath: keyPath, work: work)
        }
    }

    /// Loads data asynchronously and manages the loading state.
    ///
    /// This method handles the complete loading lifecycle for a `LoadableValue`:
    /// - Sets the state to `.loading` before starting
    /// - Executes the work closure with the environment
    /// - Sets the state to `.loaded` on success or `.failed` on error
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the `LoadableValue` property to update
    ///   - work: The asynchronous work to perform, which can throw errors
    ///
    /// Example usage:
    /// ```swift
    /// await load(store: store, keyPath: \.userProfile) { env in
    ///     try await env.userService.fetchProfile()
    /// }
    /// ```
    func load<Value, SP: StoreProtocol>(
        store: SP,
        keyPath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                await store.loadAsync(keyPath: keyPath, work: work)
            } else if let store = store as? TestStore<Self> {
                await store.loadAsync(keyPath: keyPath, work: work)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            await unsafeDowncast(store, to: Store<Self>.self)
                .loadAsync(keyPath: keyPath, work: work)
        }
    }

    /// Loads data asynchronously with transformation and manages the loading state.
    ///
    /// This method handles the complete loading lifecycle with data transformation:
    /// - Sets the state to `.loading` before starting
    /// - Executes the work closure with the environment
    /// - Transforms the result using the provided transform closure
    /// - Sets the state to `.loaded` on success or `.failed` on error
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the `LoadableValue` property to update
    ///   - work: The asynchronous work to perform, which can throw errors
    ///   - transform: A closure that transforms the work result to the state type
    ///
    /// Example usage:
    /// ```swift
    /// await load(store: store, keyPath: \.userSummary, work: { env in
    ///     try await env.userService.fetchFullProfile()
    /// }, map: { profile in
    ///     UserSummary(name: profile.name, email: profile.email)
    /// })
    /// ```
    func load<StateValue, ClientValue: Sendable, SP: StoreProtocol>(
        store: SP,
        keyPath: WritableKeyPath<State, LoadableValue<StateValue, Error>>,
        work: @Sendable @escaping (Environment) async throws -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                await store.loadAsync(keyPath: keyPath, work: work, map: transform)
            } else if let store = store as? TestStore<Self> {
                await store.loadAsync(keyPath: keyPath, work: work, map: transform)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            await unsafeDowncast(store, to: Store<Self>.self)
                .loadAsync(keyPath: keyPath, work: work, map: transform)
        }
    }

    /// Loads data for a specific key in a dictionary of `LoadableValue`s.
    ///
    /// This method manages loading state for individual items in a dictionary,
    /// allowing for granular loading control in collections.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the dictionary of `LoadableValue`s
    ///   - key: The specific key in the dictionary to load
    ///   - work: The asynchronous work to perform, which can throw errors
    ///
    /// Example usage:
    /// ```swift
    /// await load(store: store, keyPath: \.userProfiles, key: userId) { env in
    ///     try await env.userService.fetchProfile(for: userId)
    /// }
    /// ```
    func load<Key: Hashable & Sendable, Value, SP: StoreProtocol>(
        store: SP,
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                await store.loadAsync(keyPath: keyPath, key: key, work: work)
            } else if let store = store as? TestStore<Self> {
                await store.loadAsync(keyPath: keyPath, key: key, work: work)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            await unsafeDowncast(store, to: Store<Self>.self)
                .loadAsync(keyPath: keyPath, key: key, work: work)
        }
    }

    /// Executes a closure with a specific dependency from the environment.
    ///
    /// This method provides a convenient way to access and use specific dependencies
    /// from the environment without having to reference the entire environment object.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the dependency in the environment
    ///   - body: A closure that takes the dependency and returns a value
    /// - Returns: The value returned by the body closure
    ///
    /// Example usage:
    /// ```swift
    /// let isLoggedIn = withEnvironment(store: store, keyPath: \.authService) { authService in
    ///     authService.isAuthenticated
    /// }
    /// ```
    func withEnvironment<Dependency, Value, SP: StoreProtocol>(
        store: SP,
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> Value
    ) -> Value {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                return body(store.environment[keyPath: keyPath])
            } else if let store = store as? TestStore<Self> {
                return body(store.environment(keyPath))
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            return body(unsafeDowncast(store, to: Store<Self>.self).environment[keyPath: keyPath])
        }
    }

    /// Executes an asynchronous closure with a specific dependency from the environment.
    ///
    /// This method provides a convenient way to access and use specific dependencies
    /// from the environment in async contexts without having to reference the entire
    /// environment object.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keyPath: The key path to the dependency in the environment
    ///   - body: An async closure that takes the dependency and returns a value
    /// - Returns: The value returned by the body closure
    ///
    /// Example usage:
    /// ```swift
    /// let user = await withEnvironment(store: store, keyPath: \.userService) { userService in
    ///     try await userService.getCurrentUser()
    /// }
    /// ```
    func withEnvironment<Dependency: Sendable, Value, SP: StoreProtocol>(
        store: SP,
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) async -> sending Value
    ) async -> Value {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                return await body(store.environment[keyPath: keyPath])
            } else if let store = store as? TestStore<Self> {
                return await body(store.environment(keyPath))
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            return await body(unsafeDowncast(store, to: Store<Self>.self).environment[keyPath: keyPath])
        }
    }

    /// Modifies the value inside a `LoadableValue` if it's in the loaded state.
    ///
    /// This method provides a safe way to modify loaded values without having to
    /// manually check the loading state. If the `LoadableValue` is not in the
    /// `.loaded` state, the operation will be ignored and an error will be logged.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keypath: The key path to the `LoadableValue` property
    ///   - transform: A closure that modifies the loaded value in place
    ///
    /// Example usage:
    /// ```swift
    /// modifyLoadedValue(store: store, \.userProfile) { profile in
    ///     profile.lastActiveDate = Date()
    /// }
    /// ```
    func modifyLoadedValue<Value, SP: StoreProtocol>(
        store: SP,
        _ keypath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                store.state[keyPath: keypath].modify(transform: transform)
            } else if let store = store as? TestStore<Self> {
                store.state[keyPath: keypath].modify(transform: transform)
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            unsafeDowncast(store, to: Store<Self>.self).state[keyPath: keypath].modify(transform: transform)
        }
    }

    /// Modifies a value in the state using an in-place transformation.
    ///
    /// This method provides a convenient way to modify state values without
    /// having to manually get and set the value. The transformation is applied
    /// directly to the state property.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the state
    ///   - keypath: The key path to the state property to modify
    ///   - transform: A closure that modifies the value in place
    ///
    /// Example usage:
    /// ```swift
    /// modifyValue(store: store, \.settings) { settings in
    ///     settings.darkMode.toggle()
    /// }
    /// ```
    func modifyValue<Value, SP: StoreProtocol>(
        store: SP,
        _ keypath: WritableKeyPath<State, Value>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                transform(&store.state[keyPath: keypath])
            } else if let store = store as? TestStore<Self> {
                transform(&store.state[keyPath: keypath])
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            transform(&unsafeDowncast(store, to: Store<Self>.self).state[keyPath: keypath])
        }
    }

    /// Broadcasts a message to all interested subscribers in the system.
    ///
    /// Use this method to send a message conforming to `BroadcastMessage` to the
    /// global broadcast studio. This enables decoupled communication between
    /// stores, reducers, or other components that are listening for broadcast messages.
    ///
    /// - Parameter message: A message conforming to `BroadcastMessage` to be broadcast.
    ///
    /// Example usage:
    /// ```swift
    /// broadcast(UserDidSignOut())
    /// ```
    ///
    /// - Important: Use broadcasts for cross-cutting concerns or global events that
    ///   should be handled by multiple, potentially unrelated, parts of the system.
    @inlinable
    func broadcast<M: BroadcastMessage>(_ message: M) {
        BroadcastStudio.shared.publish(message)
    }

#if canImport(Combine)
    /// Subscribes to a Combine publisher from a dependency and maps its output to requests.
    ///
    /// This method enables the reducer to listen for values emitted by an `AnyPublisher` provided by a dependency in the environment.
    /// Each emitted `Result` value is mapped to an optional `Request`, which—if non-nil—will be sent to the reducer for state updates
    /// or side effects. This is useful for reacting to external or asynchronous events such as notifications, data updates, or timers
    /// published by Combine publishers.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the reducer's state and environment.
    ///   - keypath: The key path to the dependency within the environment providing the publisher.
    ///   - body: A closure that, given the dependency, returns an `AnyPublisher` whose output will be observed.
    ///   - map: A closure that maps each value emitted by the publisher to an optional `Request`. If the closure returns a non-nil value, the request is sent to the reducer.
    ///
    /// - Example:
    ///   ```swift
    ///   subscribe(store: store, keypath: \.notificationService) { service in
    ///       service.userDidChangePublisher
    ///   } map: { userId in
    ///       .userDidChange(userId)
    ///   }
    ///   ```
    ///
    /// - Note: This method is only available when the Combine framework can be imported.
	func subscribe<Dependency, Result: Sendable, SP: StoreProtocol>(
        store: SP,
        keypath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> AnyPublisher<Result, Never>,
        map: @escaping (Result) -> Request?
    ) {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                store.subscribe(
                    keypath: keypath,
                    body,
                    map: map
                )
            } else if let store = store as? TestStore<Self> {
                store.subscribe(
                    keypath: keypath,
                    body,
                    map: map
                )
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            unsafeDowncast(store, to: Store<Self>.self).subscribe(
                keypath: keypath,
                body,
                map: map
            )
        }
    }
#endif

    /// Subscribes to an asynchronous stream from a dependency and maps its output to requests.
    ///
    /// This method allows the reducer to listen for events or values emitted by an `AsyncStream` provided by a dependency in the environment.
    /// Each emitted `Result` value can be mapped to a `Request`, which will then be sent to the reducer for handling state updates or side effects.
    ///
    /// Use this to react to external async sources such as notifications, timers, or data feeds, enabling the reducer to handle updates as they occur.
    ///
    /// - Parameters:
    ///   - store: The store instance managing the reducer's state and environment.
    ///   - keypath: The key path to the dependency within the environment providing the async stream.
    ///   - body: A closure that, given the dependency, returns an `AsyncStream` of results to observe.
    ///   - map: A closure that maps each emitted result from the stream to an optional `Request`. If the closure returns a non-nil value, the request will be sent to the reducer.
    ///
    /// - Example:
    ///   ```swift
    ///   subscribe(store: store, keypath: \.timerService) { timerService in
    ///       timerService.tickStream()
    ///   } map: { _ in
    ///       .timerTick
    ///   }
    ///   ```
    ///
    /// - Note: This provides a convenient way to integrate asynchronous event streams into your state management logic using Swift Concurrency.
	func subscribe<Dependency, Result: Sendable, SP: StoreProtocol>(
        store: SP,
        keypath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> AsyncStream<Result>,
        map: @escaping (Result) -> Request?
    ) {
        if isTesting {
            #if DEBUG
            if let store = store as? Store<Self> {
                store.subscribe(
                    keypath: keypath,
                    body,
                    map: map
                )
            } else if let store = store as? TestStore<Self> {
                store.subscribe(
                    keypath: keypath,
                    body,
                    map: map
                )
            } else {
                assertionFailure("The users can only use Store and TestStore when testing. Please issue a feature request if more needs to be done")
            }
            #endif
        } else {
            unsafeDowncast(store, to: Store<Self>.self).subscribe(
                keypath: keypath,
                body,
                map: map
            )
        }
    }
}
