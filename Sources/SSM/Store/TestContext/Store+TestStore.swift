//
//  Store+TestStore.swift
//  SSM
//
//  Created by John on 10/23/25.
//

#if DEBUG
import Foundation

@MainActor
private var testStoreAssociatedKey: UInt8 = 0

extension Store {
    /// Returns a test store instance associated with this store, creating one if necessary.
    ///
    /// This method uses Objective-C associated objects to ensure that each Store instance
    /// has at most one TestStore associated with it. The TestStore is lazily created on first access
    /// and cached for subsequent calls.
    ///
    /// - Returns: A `TestStore` instance tied to this store.
    ///
    /// - Note: The TestStore is retained by the Store instance using `OBJC_ASSOCIATION_RETAIN_NONATOMIC`.
    ///         When the Store is deallocated, the associated TestStore will also be released.
    public func testStore() -> TestStore<R> {
        if let existingTestStore = objc_getAssociatedObject(self, &testStoreAssociatedKey) as? TestStore<R> {
            return existingTestStore
        }

        let newTestStore = TestStore(self)
        objc_setAssociatedObject(
            self,
            &testStoreAssociatedKey,
            newTestStore,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return newTestStore
    }

    /// Removes the associated test store from this store instance.
    ///
    /// This method can be used to explicitly clear the cached TestStore,
    /// forcing a new one to be created on the next call to `testStore()`.
    ///
    /// - Note: This is typically not necessary as the TestStore will be automatically
    ///         released when the Store is deallocated.
    public func clearTestStore() {
        objc_setAssociatedObject(
            self,
            &testStoreAssociatedKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    
    /// Checks whether this store instance has an associated test store.
    ///
    /// - Returns: `true` if a TestStore has been created and associated with this Store, `false` otherwise.
    public var hasTestStore: Bool {
        objc_getAssociatedObject(self, &testStoreAssociatedKey) != nil
    }
}
#endif
