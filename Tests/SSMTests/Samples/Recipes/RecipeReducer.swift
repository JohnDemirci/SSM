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
        case .fetchRecipes:
            await load(store: store, keyPath: \.recipes) {
                [.burger]
            }

        case .uploadRecipe:
            await load(store: store, keyPath: \.uploadRecipe) {
                EquatableVoid()
            }
        }
    }
    
    enum Request {
        case fetchRecipes
        case uploadRecipe(Recipe)
    }

    struct State {
        var recipes: LoadableValue<[Recipe], Error> = .idle
        var uploadRecipe: LoadableValue<EquatableVoid, Error> = .idle
    }
}

extension StoreContrainer where Environment == TestEnvironment {
    func recipeStore() -> Store<RecipeReducer> {
        store(
            type: Store<RecipeReducer>.self,
            state: Store<RecipeReducer>.State()
        )
    }
}
