//
//  RecipeReducer.swift
//  SSM
//
//  Created by John Demirci on 7/27/25.
//

@testable import LoadableValues
@testable import SSM
import Foundation

struct RecipeReducer: Reducer {
    func reduce(store: SSM.Store<RecipeReducer>, request: Request) async {
        switch request {
        case .fetchRecipes(let expectation):
            await load(store: store, keyPath: \.recipes) {
                try await $0.client.fetchRecipes(expectation)
            }

        case .uploadRecipe(let recipe):
            await load(store: store, keyPath: \.uploadRecipe) {
                try await $0.client.updateRecipe(recipe)
            }
        }
    }
    
    enum Request {
        case fetchRecipes([Recipe]?)
        case uploadRecipe(Recipe?)
    }

    struct State {
        var recipes: LoadableValue<[Recipe], Error> = .idle
        var uploadRecipe: LoadableValue<Void, Error> = .idle
    }

    struct Environment: Sendable {
        let client: RecipeClient
    }
}

extension StoreContrainer where Environment == TestEnvironment {
    func recipeStore() -> Store<RecipeReducer> {
        store(
            type: Store<RecipeReducer>.self,
            state: Store<RecipeReducer>.State(),
            environmentClosure: {
                Store<RecipeReducer>.Environment(client: $0.recipeClient)
            }
        )
    }
}
