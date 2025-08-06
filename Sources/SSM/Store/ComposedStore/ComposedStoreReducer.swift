//
//  ComposedStoreReducer.swift
//  SSM
//
//  Created by John Demirci on 7/22/25.
//

import Foundation

/*
 keypaths in variadic generics are broken at the moment and it is a big blocker

 https://github.com/swiftlang/swift/issues/73690
 */

//public protocol ComposedStoreReducer: Sendable {
//    associatedtype State: Sendable
//    associatedtype Request: Sendable
//    associatedtype Stores: StoreRequestAndStates
//
//    func mapRequest(_ request: Request) -> Stores.Requests
//
//    func mapState(stores: Stores.States) -> State
//
//    init()
//}
//
//public protocol StoreRequestAndStates {
//    associatedtype States
//    associatedtype Requests
//}
//
//public struct StoreTuple<each R: Reducer>: StoreRequestAndStates {
//    public typealias States = (repeat (each R).State)
//    public typealias Requests = (repeat (each R).Request?)
//}
