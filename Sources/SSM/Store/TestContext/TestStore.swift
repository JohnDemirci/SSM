//
//  TestStore.swift
//  SSM
//
//  Created by John on 10/22/25.
//

import Foundation
import Observation
import os
import LoadableValues

#if canImport(Combine)
import Combine
#endif

#if DEBUG
@MainActor
@Observable
public final class TestStore<R: Reducer>: Identifiable, @preconcurrency InternalStoreProtocol {
    public typealias State = R.State
    public typealias Request = R.Request
    public typealias Environment = R.Environment
    
    internal let reducer: R
    internal(set) public var state: State
    public let id: ReferenceIdentifier
    
    internal var subscriptionTasks: [String: Request] = [:]
    
    private var expectations: Queue<Expectation> = .init()
    
    func environment<E, V>(_ keyPath: KeyPath<Environment, E>) -> V {
        guard let book = expectations.pop() else {
            fatalError("did not find any value inside the environment")
        }
        
        guard
            book.keypath == keyPath,
            let value = book.value as? V
        else { fatalError("did not find any value inside the environment") }
        
        return value
    }
    
    func environment<E, V>(_ keyPath: KeyPath<Environment, E>) async -> V {
        guard let expectation = expectations.pop() else {
            fatalError("did not find any value inside the environment")
        }
        
        guard
            expectation.keypath == keyPath,
            let value = expectation.value as? V
        else { fatalError("did not find any value inside the environment") }
        
        if let duration = expectation.delay {
            try? await Task.sleep(for: .seconds(duration))
        }
        
        return value
    }
    
    internal let logger: Logger

    init(
        initialState: State,
        id: ReferenceIdentifier
    ) {
        self.state = initialState
        self.id = id
        self.reducer = .init()
        self.logger = Logger(subsystem: "SSM.TestStore", category: "\(R.self)_\(self.id)_Strore")
        self.reducer.setupSubscriptions(store: self)
    }
    
    public func send(_ request: sending R.Request) async {
        await reducer.reduce(store: self, request: request)
    }
    
    public func send(_ request: sending R.Request) {
        Task { await reducer.reduce(store: self, request: request) }
    }
}

extension TestStore {
    func performAsync<T>(
        keyPath: WritableKeyPath<R.State, T>,
        work: @escaping @Sendable (R.Environment) async -> sending T
    ) async {
        guard let expectation = expectations.pop() else {
            fatalError("did not find any value inside the environment")
        }
        
        guard
            expectation.keypath == keyPath,
            let value = expectation.value as? T
        else { fatalError("did not find any value inside the environment") }
        
        if let duration = expectation.delay {
            try? await Task.sleep(for: .seconds(duration))
        }
        
        self.state[keyPath: keyPath] = value
    }
    
    func performAsync<StateValue, ClientValue>(
        keyPath: WritableKeyPath<R.State, StateValue>,
        work: @escaping @Sendable (R.Environment) async -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async where ClientValue : Sendable {
        guard let expectation = expectations.pop() else {
            fatalError("did not find any value inside the environment")
        }
        
        guard
            expectation.keypath == keyPath,
            let clientValue = expectation.value as? ClientValue
        else { fatalError("did not find any value inside the environment") }
        
        if let duration = expectation.delay {
            try? await Task.sleep(for: .seconds(duration))
        }
        
        let mapped = transform(clientValue)
        
        self.state[keyPath: keyPath] = mapped
    }
    
    func performSync<T>(
        keyPath: WritableKeyPath<R.State, T>,
        work: @escaping @Sendable (R.Environment) -> T
    ) {
        guard let expectation = expectations.pop() else {
            fatalError("did not find any value inside the environment")
        }
        
        guard
            expectation.keypath == keyPath,
            let value = expectation.value as? T
        else { fatalError("did not find any value inside the environment") }
        
        self.state[keyPath: keyPath] = value
    }
    
    func loadAsync<Value>(
        keyPath: WritableKeyPath<R.State, LoadableValues.LoadableValue<Value, any Error>>,
        work: @escaping @Sendable (R.Environment) async throws -> Value
    ) async where Value : Sendable {
        guard let expectation = expectations.pop() else {
            fatalError("did not find any value inside the environment")
        }
        
        guard
            expectation.keypath == keyPath,
            let value = expectation.value as? LoadableValue<Value, any Error>
        else { fatalError("did not find any value inside the environment") }
        
        if let duration = expectation.delay {
            try? await Task.sleep(for: .seconds(duration))
        }
        
        self.state[keyPath: keyPath] = value
    }
    
    func loadAsync<StateValue, ClientValue>(
        keyPath: WritableKeyPath<R.State, LoadableValues.LoadableValue<StateValue, any Error>>,
        work: @escaping @Sendable (R.Environment) async throws -> ClientValue,
        map transform: @escaping (ClientValue) -> StateValue
    ) async where StateValue : Sendable, ClientValue : Sendable {
        fatalError("not implemented")
    }
    
    func loadAsync<Key, Value>(
        keyPath: WritableKeyPath<R.State, [Key : LoadableValues.LoadableValue<Value, any Error>]>,
        key: Key,
        work: @escaping @Sendable (R.Environment) async throws -> Value
    ) async where Key : Hashable, Key : Sendable, Value : Sendable {
        fatalError("not implemented")
    }
    
    func withEnvironment<Dependency, Value>(keyPath: KeyPath<R.Environment, Dependency>, _ body: @escaping (Dependency) -> Value) -> Value {
        return self.environment(keyPath)
    }
    
    func withEnvironment<Dependency, Value>(
        keyPath: KeyPath<R.Environment, Dependency>,
        _ body: @escaping (Dependency) async -> sending Value
    ) async -> Value where Dependency : Sendable {
        return await self.environment(keyPath)
    }
    
    func modifyLoadedValue<Value>(
        _ keypath: WritableKeyPath<R.State, LoadableValues.LoadableValue<Value, any Error>>,
        _ transform: @escaping (inout Value) -> Void
    ) where Value : Sendable {
        self.state[keyPath: keypath].modify(transform: transform)
    }
    
    func modifyValue<Value>(_ keypath: WritableKeyPath<R.State, Value>, _ transform: @escaping (inout Value) -> Void) {
        transform(&self.state[keyPath: keypath])
    }
    
    #if canImport(Combine)
    func subscribe<Dependency, Result>(
        name: String,
        keypath: KeyPath<R.Environment, Dependency>,
        _ body: @escaping (Dependency) -> AnyPublisher<Result, Never>,
        map: @escaping (Result) -> R.Request?
    ) where Result : Sendable {
        <#code#>
    }
    #endif
    
    func subscribe<Dependency, Result>(
        name: String,
        keypath: KeyPath<R.Environment, Dependency>,
        _ body: @escaping (Dependency) -> AsyncStream<Result>,
        map: @escaping (Result) -> R.Request?
    ) where Result : Sendable {
        <#code#>
    }
}

extension TestStore where State: Identifiable {
    public convenience init(
        _ state: State
    ) {
        self.init(initialState: state, id: ReferenceIdentifier(id: state.id as AnyHashable))
    }
}

extension TestStore {
    public convenience init(
        _ state: State
    ) {
        self.init(initialState: state, id: ReferenceIdentifier(id: ObjectIdentifier(Self.self) as AnyHashable))
    }
}

extension TestStore {
    struct Expectation {
        let keypath: PartialKeyPath<Environment>
        let value: Any
        let delay: TimeInterval?
        
        init(
            keypath: PartialKeyPath<Environment>,
            value: Any,
            delay: TimeInterval?
        ) {
            self.keypath = keypath
            self.value = value
            self.delay = delay
        }
    }
}

struct Queue<Element>: Sequence {
    private var storage: [Element] = []
    
    mutating func append(_ value: Element) {
        storage.append(value)
    }
    
    @discardableResult
    mutating func pop() -> Element? {
        if storage.isEmpty { return nil }
        return storage.removeFirst()
    }
    
    func makeIterator() -> some IteratorProtocol {
        storage.makeIterator()
    }
}
#endif
