//
//  Store+StateMutation.swift
//  SSM
//
//  Created by John Demirci on 7/27/25.
//

import Foundation
import LoadableValues
import SwiftUI

extension Store {
    @MainActor
    func set<T>(
        keyPath: WritableKeyPath<State, T>,
        _ value: T
    ) {
        #if DEBUG
        let previousValue = state[keyPath: keyPath]
        #endif

        self.state[keyPath: keyPath] = value

        #if DEBUG
        self.valueChanges.append(
            .init(
                keypath: keyPath,
                date: .now,
                previousValue: previousValue,
                newValue: state[keyPath: keyPath]
            )
        )
        #endif
    }

    @MainActor
    func set<Value, Key: Hashable>(
        keyPath: WritableKeyPath<State, [Key: LoadableValue<Value, Error>]>,
        key: Key,
        value: LoadableValue<Value, Error>
    ) {
        #if DEBUG
        let previousValue = state[keyPath: keyPath][key]
        #endif

        self.state[keyPath: keyPath][key] = value

        #if DEBUG
        self.valueChanges.append(
            .init(
                keypath: keyPath,
                date: .now,
                previousValue: previousValue as Any,
                newValue: state[keyPath: keyPath]
            )
        )
        #endif
    }
}

extension Store {
    func performAsync<T>(
        keyPath: WritableKeyPath<State, T>,
        work: @Sendable @escaping (Environment) async -> T
    ) async {
        let taskKey = String(describing: keyPath)
        defer {
            activeTasks.removeValue(forKey: taskKey)
        }
        let task = Task { [weak self] in
            guard let self else { return }

            let value = await work(environment)
            guard !Task.isCancelled else { return }

            self.set(keyPath: keyPath, value)
        }

        activeTasks[taskKey] = task
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

        let taskKey = String(describing: keyPath)
        activeTasks[taskKey] = task

        await task.value
        activeTasks.removeValue(forKey: taskKey)
    }

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
        #if DEBUG
        let previousValue = state[keyPath: keypath]
        #endif

        state[keyPath: keypath].modify(transform: transform)

        #if DEBUG
        valueChanges.append(
            .init(
                keypath: keypath,
                date: .now,
                previousValue: previousValue,
                newValue: state[keyPath: keypath]
            )
        )
        #endif
    }

    func modifyValue<Value>(
        _ keypath: WritableKeyPath<State, Value>,
        _ transform: @escaping (inout Value) -> Void
    ) {
        #if DEBUG
        let previousValue = state[keyPath: keypath]
        #endif

        transform(&state[keyPath: keypath])

        #if DEBUG
        valueChanges.append(
            .init(
                keypath: keypath,
                date: .now,
                previousValue: previousValue,
                newValue: state[keyPath: keypath]
            )
        )
        #endif
    }
}
