//
//  InternalStoreProtocol.swift
//  SSM
//
//  Created by John on 10/27/25.
//

#if canImport(Combine)
import Combine
#endif

internal protocol InternalStoreProtocol: StoreProtocol {
    func performAsync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) async -> sending T
    ) async

    func performAsync<StateValue, ClientValue: Sendable>(
        keyPath: WritableKeyPath<State, StateValue>,
        work: @Sendable @escaping (Environment) async -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async

    func performSync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) -> T
    )

    func loadAsync<Value>(
        keyPath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async

    func loadAsync<StateValue, ClientValue: Sendable>(
        keyPath: WritableKeyPath<State, LoadableValue<StateValue, Error>>,
        work: @Sendable @escaping (Environment) async throws -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async

    func loadAsync<Key: Hashable & Sendable, Value>(
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async

    func withEnvironment<Dependency, Value>(
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> Value
    ) -> Value

    func withEnvironment<Dependency: Sendable, Value>(
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) async -> sending Value
    ) async -> Value

    func modifyLoadedValue<Value>(
        _ keypath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        _ transform: @escaping (inout Value) -> Void
    )

    func modifyValue<Value>(
        _ keypath: WritableKeyPath<State, Value>,
        _ transform: @escaping (inout Value) -> Void
    )

    #if canImport(Combine)
    func subscribe<Dependency, Result: Sendable>(
        name: String,
        keypath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> AnyPublisher<Result, Never>,
        map: @escaping (Result) -> Request?
    )
    #endif

    func subscribe<Dependency, Result: Sendable>(
        name: String,
        keypath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> AsyncStream<Result>,
        map: @escaping (Result) -> Request?
    )
}
