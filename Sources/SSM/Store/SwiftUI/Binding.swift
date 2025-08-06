//
//  Binding.swift
//  SSM
//
//  Created by John Demirci on 7/3/25.
//

#if canImport(SwiftUI)
import SwiftUI

public extension Store {
    func binding<T>(
        _ keyPath: WritableKeyPath<State, T>,
        default: T
    ) -> Binding<T> {
        Binding(
            get: { [weak self] in
                self?.state[keyPath: keyPath] ?? `default`
            },
            set: { newValue, transaction in
                Task { @MainActor [weak self] in
                    withTransaction(transaction) {
                        self?.state[keyPath: keyPath] = newValue
                    }
                }
            }
        )
    }

    func binding<T>(
        _ keyPath: WritableKeyPath<State, T?>,
    ) -> Binding<T?> {
        Binding(
            get: { [weak self] in
                self?.state[keyPath: keyPath]
            },
            set: { newValue in
                Task { @MainActor [weak self] in
                    self?.state[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

public extension Binding {
    @MainActor
    static func state<R: Reducer, V>(
        from store: Store<R>,
        _ keyPath: WritableKeyPath<R.State, V>,
        default: V
    ) -> Binding<V> {
        store.binding(keyPath, default: `default`)
    }

    @MainActor
    init<R: Reducer>(
        from store: Store<R>,
        _ keyPath: WritableKeyPath<R.State, Value>,
        default: Value
    ) {
        self = .init(projectedValue: store.binding(keyPath, default: `default`))
    }
}

#endif
