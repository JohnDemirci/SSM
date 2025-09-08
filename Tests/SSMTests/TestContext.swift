//
//  TestContext.swift
//  SSM
//
//  Created by John Demirci on 9/5/25.
//

import Testing
@testable import SSM

@MainActor
@Suite("testcontext")
struct TestContextTests {
    @Test
    func something() async throws {
        let recipeStore = Store<RecipeReducer>.init(
            initialState: .init(), environment: ()
        )

        await recipeStore.send(.fetchRecipes)

        recipeStore.testContext?.makeValueForAwaitingKeypath(
            for: \.recipes, .loaded(.init(value: [.burger], timestamp: .now))
        ) {
            #expect($0.recipes.value == [.burger])
        }
    }
}
