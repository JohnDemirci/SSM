import Foundation

/// A container that manages and caches `Store` instances for various reducers and environments.
///
/// `StoreContrainer` provides a mechanism to associate and reuse `Store` instances based on
/// either a unique state identifier or a store type, ensuring that each store instance is
/// uniquely scoped to its intended identity. This is particularly useful in applications
/// that require state isolation or sharing across different parts of the app.
///
/// The container holds a root environment value and allows reducers to access their own
/// scoped environment via a closure, supporting environment injection and modular state management.
///
/// - Note: Store instances are held via weak references, allowing them to be deallocated
///   when no longer in use. Attempting to retrieve a store after it has been deallocated
///   will create a new instance.
///
/// - Important: `StoreContrainer` is designed for use on the main actor and is observable.
///   It requires its environment type to conform to `Sendable`.
///
/// - Parameters:
///   - Environment: The type of the root environment provided to reducers.
@MainActor
@Observable
public final class StoreContrainer<Environment: Sendable>: Sendable {
    private var stores: NSMapTable<ReferenceIdentifier, AnyObject>
    private let environment: Environment

    public init(environment: Environment) {
        stores = NSMapTable<ReferenceIdentifier, AnyObject>(
            keyOptions: .weakMemory,
            valueOptions: .weakMemory
        )

        self.environment = environment
    }

    /// Returns a cached `Store` instance for the given state if one exists; otherwise, creates a new `Store` with the provided state and environment.
    ///
    /// This method ensures that a unique store instance is associated with each distinct state identifier.
    /// If a store has already been created and cached for the specified state's identifier, the existing store is returned.
    /// Otherwise, a new store is initialized with the given state and environment derived from the provided closure, then cached for future retrieval.
    ///
    /// - Parameters:
    ///   - state: The initial state for the store to be retrieved or created. The state type must conform to `Identifiable`.
    ///   - environmentClosure: A closure that maps the container's root environment to the environment required by the reducer.
    ///
    /// - Returns: A `Store` instance for the specified reducer and state.
    /// 
    /// - Note: Store instances are uniquely associated to the identity of the provided state.
    public func store<R: Reducer>(
        state: R.State,
        environmentClosure: @Sendable @escaping (Environment) -> R.Environment
    ) -> Store<R> where R.State: Identifiable {
        let id = ReferenceIdentifier(id: state.id as AnyHashable)
        if let existingStore = stores.object(forKey: id) as? Store<R> {
            return existingStore
        } else {
            let newStore = Store<R>(
                initialState: state,
                environment: environmentClosure(environment)
            )
            stores.setObject(newStore, forKey: newStore.id)
            return newStore
        }
    }

    /// Returns a cached `Store` instance associated with the specified store type, or creates a new one if none exists.
    ///
    /// This method enables the creation and retrieval of shared or singleton store instances scoped to the provided type,
    /// rather than to a specific state identifier. This is useful for stores that are meant to be unique per type rather than per state instance.
    ///
    /// - Parameters:
    ///   - type: The metatype of the `Store` to retrieve or create. Defaults to `Store<R>.self`.
    ///   - state: The initial state for the store. This value is only used if a store does not already exist for the specified type.
    ///   - environmentClosure: A closure that maps the container's root environment to the environment required by the reducer.
    ///
    /// - Returns: A `Store` instance associated with the given type, initialized with the provided state and environment if not already cached.
    ///
    /// - Note: Store instances are uniquely associated to the identity of the provided type (not the state). Use this to create global or shared stores.
    public func store<R: Reducer>(
        type: Store<R>.Type = Store<R>.self,
        state: R.State,
        environmentClosure: @Sendable @escaping (Environment) -> R.Environment
    ) -> Store<R> {
        let id = ReferenceIdentifier(id: ObjectIdentifier(type) as AnyHashable)
        if let existingStore = stores.object(forKey: id) as? Store<R> {
            return existingStore
        } else {
            let newStore = Store<R>(
                initialState: state,
                environment: environmentClosure(environment)
            )
            stores.setObject(newStore, forKey: newStore.id)
            return newStore
        }
    }

    public func store<R: Reducer>(
        type: Store<R>.Type = Store<R>.self,
        state: R.State
    ) -> Store<R> where R.Environment == Void {
        let id = ReferenceIdentifier(id: ObjectIdentifier(type) as AnyHashable)
        if let existingStore = stores.object(forKey: id) as? Store<R> {
            return existingStore
        } else {
            let newStore = Store<R>(
                initialState: state,
                environment: ()
            )
            stores.setObject(newStore, forKey: newStore.id)
            return newStore
        }
    }

    public func store<R: Reducer>(
        state: R.State
    ) -> Store<R> where R.State: Identifiable, R.Environment == Void {
        let id = ReferenceIdentifier(id: state.id as AnyHashable)
        if let existingStore = stores.object(forKey: id) as? Store<R> {
            return existingStore
        } else {
            let newStore = Store<R>(
                initialState: state,
                environment: ()
            )
            stores.setObject(newStore, forKey: newStore.id)
            return newStore
        }
    }
}
