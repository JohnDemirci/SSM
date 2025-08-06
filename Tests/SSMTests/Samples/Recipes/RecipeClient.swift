//
//  RecipeClient.swift
//  SSM
//
//  Created by John Demirci on 7/27/25.
//

import Foundation

final class RecipeClient: Sendable {
    struct Failure: Error {}
}

extension RecipeClient {
    func fetchRecipes(_ expectation: [Recipe]?) async throws -> [Recipe] {
        guard let expectation else { throw Failure() }

        try await Task.sleep(for: .seconds(0.5))

        return expectation
    }

    func updateRecipe(
        _ recipe: Recipe?
    ) async throws {
        if recipe == nil {
            throw Failure()
        }
        try await Task.sleep(for: .seconds(0.5))
    }
}
