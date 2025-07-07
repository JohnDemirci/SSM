import Foundation
import LoadableValues
import SwiftUI

public typealias StoreOf<R: Reducer> = Store<R>

@Observable
@MainActor
@dynamicMemberLookup
public final class Store<R: Reducer>: @MainActor StoreProtocol {
    public typealias State = R.State
    public typealias Request = R.Request
    public typealias Environment = R.Environment

    let environment: Environment
    public internal(set) var state: State
    private let reducer: R

    private var activeTasks: [String: Task<Void, Never>] = [:]

    public init(
        initialState: State,
        environment: Environment,
    ) {
        self.state = initialState
        self.environment = environment
        self.reducer = .init()
    }

    @MainActor
    deinit {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    public subscript<S>(dynamicMember keyPath: KeyPath<State, S>) -> S {
        state[keyPath: keyPath]
    }

    public func send(_ request: sending Request) async {
        await reducer.reduce(store: self, request: request)
    }

    public func send(_ request: Request) {
        Task { @MainActor in await reducer.reduce(store: self, request: request) }
    }
}

public extension Store {
    func cancelActiveTask<V>(
        for keyPath: WritableKeyPath<State, LoadableValue<V, Error>>
    ) {
        let taskKey = String(describing: keyPath)
        if let task = activeTasks[taskKey] {
            task.cancel()
            activeTasks.removeValue(forKey: taskKey)
            Task { @MainActor [weak self] in
                self?.state[keyPath: keyPath] = .cancelled(.now)
            }
        }
    }

    func cancelActiveTask<V, K: Hashable & Sendable>(
        for keyPath: WritableKeyPath<State, [K: LoadableValue<V, Error>]>,
        key: K
    ) {
        let taskKey = String(describing: keyPath) + String(describing: key)
        if let task = activeTasks[taskKey] {
            task.cancel()
            activeTasks.removeValue(forKey: taskKey)
            Task { @MainActor [weak self] in
                self?.state[keyPath: keyPath][key] = .cancelled(.now)
            }
        }
    }

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

extension Store {
    func performAsync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) async -> T
    ) async {
        let task = Task { [environment] in
            let value = await work(environment)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                state[keyPath: keyPath] = value
            }
        }

        let taskKey = String(describing: keyPath)
        activeTasks[taskKey] = task

        await task.value

        activeTasks.removeValue(forKey: taskKey)
    }

    func performAsync<StateValue, ClientValue: Sendable>(
        keyPath: WritableKeyPath<State, StateValue>,
        work: @Sendable @escaping (Environment) async -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async {
        let task = Task { [environment] in
            let value = await work(environment)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                state[keyPath: keyPath] = transform(value)
            }
        }

        let taskKey = String(describing: keyPath)
        activeTasks[taskKey] = task

        await task.value
        activeTasks.removeValue(forKey: taskKey)
    }

    func performSync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) -> T
    ) {
        let value = work(environment)
        state[keyPath: keyPath] = value
    }

    func loadAsync<Value>(
        keyPath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        if case .loading = state[keyPath: keyPath] {
            #if DEBUG
                assertionFailure("Currently another operation is loading value")
            #endif
            return
        }

        state[keyPath: keyPath] = .loading

        let task = Task { [environment] in
            do {
                let data = try await work(environment)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state[keyPath: keyPath] = .loaded(
                        LoadingSuccess(value: data, timestamp: Date.now)
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state[keyPath: keyPath] = .failed(
                        LoadingFailure(failure: error, timestamp: Date.now)
                    )
                }
            }
        }
        activeTasks[String(describing: keyPath)] = task
        await task.value
        activeTasks.removeValue(forKey: String(describing: keyPath))
    }

    func loadAsync<StateValue, ClientValue: Sendable>(
        keyPath: WritableKeyPath<State, LoadableValue<StateValue, Error>>,
        work: @Sendable @escaping (Environment) async throws -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async {
        if case .loading = state[keyPath: keyPath] {
            #if DEBUG
                assertionFailure("Currently another operation is loading value")
            #endif
            return
        }

        state[keyPath: keyPath] = .loading

        let task = Task { [environment] in
            do {
                let value = try await work(environment)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state[keyPath: keyPath] = .loaded(
                        LoadingSuccess(value: transform(value), timestamp: Date.now)
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state[keyPath: keyPath] = .failed(
                        LoadingFailure(failure: error, timestamp: Date.now)
                    )
                }
            }
        }
        activeTasks[String(describing: keyPath)] = task
        await task.value
        activeTasks.removeValue(forKey: String(describing: keyPath))
    }

    func loadAsync<Key: Hashable & Sendable, Value>(
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        if state[keyPath: keyPath][key] == nil {
            state[keyPath: keyPath][key] = .idle
        }

        if case .loading = state[keyPath: keyPath][key] {
            #if DEBUG
                assertionFailure("Currently another operation is loading value")
            #endif
            return
        }

        state[keyPath: keyPath][key] = .loading

        let task = Task { [environment] in
            do {
                let value = try await work(environment)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state[keyPath: keyPath][key] = .loaded(
                        LoadingSuccess(value: value, timestamp: Date.now)
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    state[keyPath: keyPath][key] = .failed(
                        LoadingFailure(failure: error, timestamp: Date.now)
                    )
                }
            }
        }
        activeTasks[String(describing: keyPath) + String(describing: key)] = task
        await task.value
        activeTasks.removeValue(forKey: String(describing: keyPath) + String(describing: key))
    }

    func withEnvironment<Dependency, Value>(
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> Value
    ) -> Value {
        return body(environment[keyPath: keyPath])
    }

    func withEnvironment<Dependency: Sendable, Value>(
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) async -> Value
    ) async -> Value {
        return await body(environment[keyPath: keyPath])
    }

    func modifyLoadedValue<Value>(
        _ keypath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        state[keyPath: keypath].modify(transform: transform)
    }

    func modifyValue<Value>(
        _ keypath: WritableKeyPath<State, Value>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        transform(&state[keyPath: keypath])
    }
}
