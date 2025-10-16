//
//  TestContext.swift
//  SSM
//
//  Created by John Demirci on 9/4/25.
//

import Foundation
import os

#if DEBUG
@MainActor
public final class TestContext<R: Reducer> {
    private weak var context: Store<R>?
    private let logger = Logger(subsystem: "SSM.TestContext", category: "keypath-management")

    nonisolated(unsafe)
    var keypathsToUpdate: [PartialKeyPath<R.State>] = []

    public init(context: Store<R>) {
        self.context = context
    }

    deinit {
        if !keypathsToUpdate.isEmpty {
            assertionFailure("Deinitializing the Test Context while items waiting to be asserted: \(keypathsToUpdate)")
        }
    }
}

extension TestContext {
    func setExpectationForActionOnKeyPath<T>(
        keyPath: WritableKeyPath<R.State, T>
    ) {
        guard keypathsToUpdate.isEmpty else {
            fatalError("Attempting to perform a test action while items are still waiting to be asserted \(keypathsToUpdate)")
        }

        keypathsToUpdate.append(keyPath)
    }

    public func makeValueForAwaitingKeypath<T>(
        for keypath: WritableKeyPath<R.State, T>,
        _ value: T,
        completion: @Sendable @escaping (Store<R>.State) -> Void
    ) {
        let keypathIndex = keypathsToUpdate.firstIndex(of: keypath)

        guard let keypathIndex else {
            fatalError("unable to find the index of the keypath: \(keypath) inside the \(keypathsToUpdate)")
        }

        let awaitingTypeErasedKeypath = keypathsToUpdate[keypathIndex]

        guard let awaitingKeypath = awaitingTypeErasedKeypath as? WritableKeyPath<R.State, T> else {
            fatalError("unable to convert the \(awaitingTypeErasedKeypath) to type \(WritableKeyPath<R.State, T>.self)")
        }

        self.context!.state[keyPath: awaitingKeypath] = value
        keypathsToUpdate.remove(at: keypathIndex)

        guard let store = context else {
            fatalError("store is deallocated")
        }

        completion(store.state)
    }

    public func forget<T>(
        keypath: KeyPath<R.State, T>
    ) {
        let keypathIndex = keypathsToUpdate.firstIndex(of: keypath)

        if let keypathIndex {
            keypathsToUpdate.remove(at: keypathIndex)
        } else {
            logger.fault("Attempted to remove a keypath that does not exist within the queue")
        }
    }
}
#endif
