import Foundation

@Observable
@dynamicMemberLookup
public final class BoxedState<R: Reducer, StoreValue, MappedValue>: @unchecked Sendable {
    @usableFromInline
    internal let store: Store<R>

    @usableFromInline
    internal let keyPath: KeyPath<Store<R>.State, StoreValue>

    @usableFromInline
    internal let map: (StoreValue) -> MappedValue

    @MainActor
    @inlinable
    public subscript<T>(dynamicMember keyPath: KeyPath<MappedValue, T>) -> T {
        value[keyPath: keyPath]
    }

    /// The current value derived from the reducer's state, mapped to type `K`.
    ///
    /// Accessing this property will observe and transform the value at the specified key path in the store's state.
    /// The value is computed by applying the `map` closure to the value at the key path.
    ///
    /// - Note: Accessing this property also enables state observation for SwiftUI and other observation-driven mechanisms.
    @MainActor
    @ObservationTracked
    @inlinable
    public var value: MappedValue { map(store.state[keyPath: keyPath]) }

    /// Initializes a new instance of `BoxedState`, observing and transforming a specific value in the reducer's state.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to a value within the state of the provided store.
    ///   - store: The store that holds the reducer state to be observed.
    ///   - map: A closure that maps the value at the given key path (`T`) to a value of type `K`.
    ///
    /// This initializer allows you to observe a value in the state and optionally transform it into another type.
    public init(
        of keyPath: KeyPath<Store<R>.State, StoreValue>,
        in store: Store<R>,
        map: @escaping (StoreValue) -> MappedValue
    ) {
        self.store = store
        self.keyPath = keyPath
        self.map = map
        
        Task { @MainActor [weak self] in
            self?.observe()
        }
    }

    @MainActor
    private func observe() {
        withObservationTracking {
            _ = store.state[keyPath: keyPath]
        } onChange: {
            Task { @MainActor [weak self] in
                self?.observe()
            }
        }
    }
}

extension BoxedState where StoreValue == MappedValue {
    /// Creates a ``BoxedState`` instance that observes a specific value in the reducer's state.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the value in the reducer's state to observe.
    ///   - store: The store whose state will be accessed.
    ///
    /// This initializer is only available when the output type `K` is the same as the value type `T`.
    public convenience init(
        of keyPath: KeyPath<Store<R>.State, StoreValue>,
        in store: Store<R>
    ) {
        self.init(
            of: keyPath,
            in: store,
            map: \.self
        )
    }
}
