//
//  StoreInstanceTests.swift
//  SSM
//
//  Created by John Demirci on 7/27/25.
//

@testable import LoadableValues
@testable import SSM
import Testing

@MainActor
@Suite("StoreInstanceTests")
struct StoreInstanceTests {
    @Test("Stores without an identifiable state should use self as unique identifier and do not spawn identical stores")
    func onlyOneStoreForEachAttempt() async throws {
        let container = StoreContrainer(environment: TestEnvironment())
        let recipeStore1 = container.recipeStore()
        let recipeStore2 = container.recipeStore()
        let recipeStore3 = container.recipeStore()

        #expect(recipeStore1 === recipeStore2)
        #expect(recipeStore1 === recipeStore3)
    }

    @Test("Store with Void Environment and Self IDed should only have one instance")
    func onlyOneStoreEachAttempt2() async {
        let container = StoreContrainer(environment: TestEnvironment())
        let navigationStore1 = container.navigationStore()
        let navigationStore2 = container.navigationStore()
        let navigationStore3 = container.navigationStore()

        #expect(navigationStore1 === navigationStore2)
        #expect(navigationStore2 === navigationStore3)
    }

    @Test("When a Store is no longer in the lifetime of the current scope it should be automatically deallocated")
    func testDeallocation() async throws {
        let container = StoreContrainer(environment: TestEnvironment())

        func scope() async {
            let store1 = container.recipeStore()
            await store1.send(.fetchRecipes)

            store1.testContext?.makeValueForAwaitingKeypath(for: \.recipes, .idle) {
                #expect($0.recipes.value == nil)
            }

            //#expect(store1.recipes.value == nil)
        }

        await scope()

        try await Task.sleep(for: .seconds(2))
    }
}
