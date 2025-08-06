//
//  ComposedStoreProtocol.swift
//  SSM
//
//  Created by John Demirci on 7/22/25.
//

public protocol ComposedStoreProtocol: StoreProtocol {
    associatedtype Environment = Void
}
