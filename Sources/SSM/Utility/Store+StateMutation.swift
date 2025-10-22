//
//  Store+StateMutation.swift
//  SSM
//
//  Created by John Demirci on 7/27/25.
//

import Combine
import Foundation
import LoadableValues
import SwiftUI

extension Store {
    @inline(__always)
    @MainActor
    func set<T>(
        keyPath: WritableKeyPath<State, T>,
        _ value: T
    ) {
        self.state[keyPath: keyPath] = value
    }

    @inline(__always)
    @MainActor
    func set<Value, Key: Hashable>(
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        value: LoadableValue<Value, Error>
    ) {
        self.state[keyPath: keyPath][key] = value
    }
}

extension Store {
    func performAsync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) async -> sending T
    ) async {
        defer {
            _ = activeTasksLock.withLock {
                activeTasks.removeValue(forKey: keyPath)
            }
        }
        let task = Task { [weak self] in
            guard let self else { return }

            let value = await work(environment)
            guard !Task.isCancelled else { return }

            self.set(keyPath: keyPath, value)
        }

        activeTasksLock.withLock {
            activeTasks[keyPath] = task
        }
        
        await task.value
    }

    func performAsync<StateValue, ClientValue: Sendable>(
        keyPath: WritableKeyPath<State, StateValue>,
        work: @Sendable @escaping (Environment) async -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async {
        let task = Task { [weak self] in
            guard let self else { return }
            let value = await work(self.environment)
            guard !Task.isCancelled else { return }
            self.set(keyPath: keyPath, transform(value))
        }

        activeTasksLock.withLock {
            activeTasks[keyPath] = task
        }

        await task.value
        
        _ = activeTasksLock.withLock {
            activeTasks.removeValue(forKey: keyPath)
        }
    }

    @inline(__always)
    func performSync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) -> T
    ) {
        self.set(keyPath: keyPath, work(environment))
    }

    func loadAsync<Value>(
        keyPath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        if case .loading = state[keyPath: keyPath] {
            #if DEBUG
            assertionFailure("Currently another operation is loading value")
            #else
            dump("another process is currently being executed")
            #endif
            return
        }

        self.set(keyPath: keyPath, .loading)

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await work(self.environment)
                guard !Task.isCancelled else { return }
                self.set(
                    keyPath: keyPath,
                    .loaded(
                        LoadingSuccess(value: data, timestamp: Date.now)
                    )
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.set(
                    keyPath: keyPath,
                    .failed(
                        LoadingFailure(failure: error, timestamp: Date.now)
                    )
                )
            }
        }
        
        activeTasksLock.withLock {
            activeTasks[keyPath] = task
        }
        await task.value
        _ = activeTasksLock.withLock {
            activeTasks.removeValue(forKey: keyPath)
        }
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

        self.set(keyPath: keyPath, .loading)

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let value = try await work(environment)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.set(
                        keyPath: keyPath,
                        .loaded(
                            LoadingSuccess(value: transform(value), timestamp: Date.now)
                        )
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }

                self.set(
                    keyPath: keyPath,
                    .failed(
                        LoadingFailure(failure: error, timestamp: Date.now)
                    )
                )
            }
        }

        activeTasksLock.withLock {
            activeTasks[keyPath] = task
        }
        await task.value
        _ = activeTasksLock.withLock {
            activeTasks.removeValue(forKey: keyPath)
        }
    }

    func loadAsync<Key: Hashable & Sendable, Value>(
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        work: @Sendable @escaping (Environment) async throws -> Value
    ) async {
        if state[keyPath: keyPath][key] == nil {
            self.set(keyPath: keyPath, key: key, value: .idle)
        }

        if case .loading = state[keyPath: keyPath][key] {
            #if DEBUG
                assertionFailure("Currently another operation is loading value")
            #endif
            return
        }

        self.set(keyPath: keyPath, key: key, value: .loading)

        let task = Task { [environment] in
            do {
                let value = try await work(environment)
                guard !Task.isCancelled else { return }

                self.set(
                    keyPath: keyPath,
                    key: key,
                    value: .loaded(
                        LoadingSuccess(value: value, timestamp: Date.now)
                    )
                )
            } catch {
                guard !Task.isCancelled else { return }

                self.set(
                    keyPath: keyPath,
                    key: key,
                    value: .failed(
                        LoadingFailure(failure: error, timestamp: Date.now)
                    )
                )
            }
        }

        let taskKey = String(describing: keyPath) + String(describing: key)

        activeTasksLock.withLock {
            activeTasks[taskKey] = task
        }
        
        await task.value
        
        _ = activeTasksLock.withLock {
            activeTasks.removeValue(forKey: taskKey)
        }
    }

    func withEnvironment<Dependency, Value>(
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> Value
    ) -> Value {
        return body(environment[keyPath: keyPath])
    }

    func withEnvironment<Dependency: Sendable, Value>(
        keyPath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) async -> sending Value
    ) async -> Value {
        return await body(environment[keyPath: keyPath])
    }

    func modifyLoadedValue<Value>(
        _ keypath: WritableKeyPath<State, LoadableValue<Value, Error>>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        state[keyPath: keypath].modify(transform: transform)
    }

    @inline(__always)
    func modifyValue<Value>(
        _ keypath: WritableKeyPath<State, Value>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        transform(&state[keyPath: keypath])
    }

	func subscribe<Dependency, Result: Sendable>(
        keypath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> AnyPublisher<Result, Never>,
        map: @escaping (Result) -> Request?
    ) {
        let model = environment[keyPath: keypath]
        let stream = body(model)

        let id = UUID()

        self.subscriptionTaskLock.withLock {
            self.subscriptionTasks[id] = Task { [weak self] in
                for await value in stream.values {
                    guard let self else { return }
                    let request = map(value)

                    guard let request else { continue }

                    Task { @MainActor in
                        self.send(request)
                    }
                }
            }
        }
    }

	func subscribe<Dependency, Result: Sendable>(
        keypath: KeyPath<Environment, Dependency>,
        _ body: @escaping (Dependency) -> AsyncStream<Result>,
        map: @escaping (Result) -> Request?
    ) {
        let model = environment[keyPath: keypath]
        let stream = body(model)

        let id = UUID()
        
        self.subscriptionTaskLock.withLock {
            self.subscriptionTasks[id] = Task { [weak self] in
                for await result in stream {
                    guard let self else { return }
                    let request = map(result)

                    guard let request else { continue }

                    Task { @MainActor in
                        self.send(request)
                    }
                }
            }
        }

        Task { [weak self] in
            guard let self else { return }
            await self.subscriptionTasks[id]?.value
        }
    }
}
