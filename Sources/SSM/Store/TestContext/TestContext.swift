//
//  TestContext.swift
//  SSM
//
//  Created by John Demirci on 9/4/25.
//

import IssueReporting

@MainActor
public final class TestContext<R: Reducer> {
    private weak var context: Store<R>?

    nonisolated(unsafe)
    var keypathsToUpdate: [PartialKeyPath<R.State>] = []

    public init(context: Store<R>) {
        self.context = context
        IssueReporters.current = [.fatalError]
    }

    deinit {
        if !keypathsToUpdate.isEmpty {
            reportIssue("Deinitializing the Test Context while items waiting to be asserted: \(keypathsToUpdate)")
        }
    }
}

extension TestContext {
    func setExpectationForActionOnKeyPath<T>(
        keyPath: WritableKeyPath<R.State, T>
    ) {
        guard keypathsToUpdate.isEmpty else {
            reportIssue("Attempting to perform a test action while items are still waiting to be asserted \(keypathsToUpdate)")
            return
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
            reportIssue("unable to find the index of the keypath: \(keypath) inside the \(keypathsToUpdate)")
            return
        }

        let awaitingTypeErasedKeypath = keypathsToUpdate[keypathIndex]

        guard let awaitingKeypath = awaitingTypeErasedKeypath as? WritableKeyPath<R.State, T> else {
            reportIssue("unable to convert the \(awaitingTypeErasedKeypath) to type \(WritableKeyPath<R.State, T>.self)")
            return
        }

        self.context!.state[keyPath: awaitingKeypath] = value
        keypathsToUpdate.remove(at: keypathIndex)

        guard let store = context else {
            reportIssue("store is deallocated")
            return
        }

        completion(store.state)
    }

    public func forget<T>(
        keypath: KeyPath<R.State, T>
    ) {
        let keypathIndex = keypathsToUpdate.firstIndex(of: keypath)

        defer {
            IssueReporters.current = [.fatalError]
        }

        if let keypathIndex {
            keypathsToUpdate.remove(at: keypathIndex)
        } else {
            IssueReporters.current = [.runtimeWarning]
            reportIssue("Attempted to remove a keypath that does not exists within the queue")
        }
    }
}
