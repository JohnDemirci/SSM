//
//  Reducer.swift
//  SSM
//
//  Created by John Demirci on 7/3/25.
//

import Foundation
import LoadableValues

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
    associatedtype State
    associatedtype Request
    associatedtype Environment: Sendable

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
    func reduce(
        store: Store<Self>,
        request: Request
    ) async

    /// Creates a new instance of the reducer.
    ///
    /// The reducer must be initializable without parameters to support
    /// the store's initialization process.
    init()
}

extension Reducer {
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
    func perform<T>(
        store: Store<Self>,
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) async -> T
    ) async {
        await store.performAsync(keyPath: keyPath, work: work)
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
    func perform<StateValue, ClientValue: Sendable>(
        store: Store<Self>,
        keyPath: WritableKeyPath<State, StateValue>,
        work: @Sendable @escaping (Environment) async -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async {
        await store.performAsync(keyPath: keyPath, work: work, map: transform)
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
    func perform<T>(
        store: Store<Self>,
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) -> T
    ) {
        store.performSync(keyPath: keyPath, work: work)
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
    func load<Value>(
        store: Store<Self>,
        keyPath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        await store.loadAsync(keyPath: keyPath, work: work)
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
    func load<StateValue, ClientValue: Sendable>(
        store: Store<Self>,
        keyPath: WritableKeyPath<State, LoadableValue<StateValue, Error>>,
        work: @Sendable @escaping (Environment) async throws -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async {
        await store.loadAsync(keyPath: keyPath, work: work, map: transform)
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
    func load<Key: Hashable & Sendable, Value>(
        store: Store<Self>,
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        await store.loadAsync(keyPath: keyPath, key: key, work: work)
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
    func withEnvironment<Dependency, Value>(
        store: Store<Self>,
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> Value
    ) -> Value {
        return body(store.environment[keyPath: keyPath])
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
    func withEnvironment<Dependency: Sendable, Value>(
        store: Store<Self>,
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) async -> Value
    ) async -> Value {
        return await body(store.environment[keyPath: keyPath])
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
    func modifyLoadedValue<Value>(
        store: Store<Self>,
        _ keypath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        store.state[keyPath: keypath].modify(transform: transform)
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
    func modifyValue<Value>(
        store: Store<Self>,
        _ keypath: WritableKeyPath<State, Value>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        transform(&store.state[keyPath: keypath])
    }
}
