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
    
    #if swift(>=6.2)
    @MainActor
    deinit {
        if !keypathsToUpdate.isEmpty {
            issueFailure("Deinitializing the Test Context while items waiting to be asserted: \(keypathsToUpdate)")
        }
    }
    #else
    deinit {
        let keypaths = keypathsToUpdate
        
        if !keypaths.isEmpty {
            logger.fault("deinitilizing the Text Context while items waiting to be asserted: \(keypaths)")
        }
    }
    #endif
}

extension TestContext {
    func setExpectationForActionOnKeyPath<T>(
        keyPath: WritableKeyPath<R.State, T>
    ) {
        let keypaths = keypathsToUpdate
        guard keypaths.isEmpty else {
            issueFailure("Attempting to perform a test action while items are still waiting to be asserted \(keypaths)")
            return
        }

        keypathsToUpdate.append(keyPath)
    }

    public func makeValueForAwaitingKeypath<T>(
        for keypath: WritableKeyPath<R.State, T>,
        _ value: T,
        completion: @Sendable @escaping (Store<R>.State) -> Void
    ) {
        let keypaths = self.keypathsToUpdate
        
        let keypathIndex = keypathsToUpdate.firstIndex(of: keypath)
        let keypathStringRepresentation = "\(keypath)"

        guard let keypathIndex else {
            issueFailure("unable to find the index of the keypath: \(keypathStringRepresentation) inside the \(keypaths)")
            return
        }

        let awaitingTypeErasedKeypath = keypathsToUpdate[keypathIndex]
        let awaitingTypeErasedKeypathString = "\(awaitingTypeErasedKeypath)"

        guard let awaitingKeypath = awaitingTypeErasedKeypath as? WritableKeyPath<R.State, T> else {
            issueFailure("unable to convert the \(awaitingTypeErasedKeypathString) to type \(WritableKeyPath<R.State, T>.self)")
            return
        }

        self.context!.state[keyPath: awaitingKeypath] = value
        keypathsToUpdate.remove(at: keypathIndex)

        guard let store = context else {
            issueFailure("store is deallocated")
            return
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

private extension TestContext {
    func issueFailure(_ message: String) {
		assertionFailure(message)
	}
}
#endif
