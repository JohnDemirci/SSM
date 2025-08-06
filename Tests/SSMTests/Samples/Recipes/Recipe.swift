//
//  Recipe.swift
//  SSM
//
//  Created by John Demirci on 7/27/25.
//

struct Recipe: Equatable {
    let ingredients: [String]
    let instructions: [String]
    let name: String
}

extension Recipe {
    static let scrambledEggs = Recipe(
        ingredients: ["4x eggs", "salt", "pepper"],
        instructions: [
            "break the eggs",
            "add salt",
            "add pepper"
        ],
        name: "scrambled eggs"
    )

    static let burger = Recipe(
        ingredients: [
            "bun",
            "patties",
            "cheese",
            "lettuce",
            "tomato",
            "mayonnaise",
            "mustard",
            "ketchup",
            "salt",
            "pepper"
        ],
        instructions: [
            "heat up the pan",
            "cut the tomatos in a in half and make circular slices",
            "season the patties with salt and pepper",
            "place the patties in the pan",
            "cook the patties for 4-5 minutes on each side",
            "place the cheese on top of the patties",
            "place the lettuce and tomato slices on top of the cheese",
            "spread mayonnaise and mustard on the bun bottoms",
            "close the buns around the filling",
            "serve immediately"
        ],
        name: "Classic Burger"
    )

    static let grilledCheeseSandwich = Recipe(
        ingredients: ["bread", "cheese", "butter"],
        instructions: [
            "Butter one side of each slice of bread",
            "Place the cheese and buttered side of one slice of bread, butter side down, on a clean surface",
            "Place the other slice of bread, butter side up, on top of the cheese to make a sandwich",
        ],
        name: "Grilled Cheese Sandwich"
    )
}
