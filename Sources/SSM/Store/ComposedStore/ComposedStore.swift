//
//  ComposedStore.swift
//  SSM
//
//  Created by John Demirci on 7/22/25.
//

import Observation

/*
 keypaths in variadic generics are broken in Swift Programming Language

 https://github.com/swiftlang/swift/issues/73690
 */
//@Observable
//@MainActor
//final class ComposedStore<
//    CR: ComposedStoreReducer, each R: Reducer
//> where CR.Stores == StoreTuple<repeat each R> {
//    public typealias State = CR.State
//    public typealias Request = CR.Request
//
//    public private(set) var state: State
//    private let stores: (repeat Store<each R>)
//    private let reducer: CR
//
//    public init(_ stores: repeat Store<each R>) {
//        let reducer = CR()
//        self.stores = (repeat each stores)
//        self.reducer = reducer
//
//        let currentStates = (repeat (each stores).state)
//        self.state = reducer.mapState(stores: currentStates)
//
//        self.observeStores()
//    }
//
//    public func send(_ request: sending CR.Request) {
//        let mappedRequests = reducer.mapRequest(request)
//
//        func sendToStore<Red: Reducer>(
//            _ store: Store<Red>,
//            _ request: Red.Request?
//        ) {
//            if let request = request {
//                store.send(request)
//            }
//        }
//
//        repeat sendToStore(each stores, each mappedRequests)
//    }
//
//    public func send(_ request: sending CR.Request) async {
//        let mappedRequests = reducer.mapRequest(request)
//
//        func sendToStore<Red: Reducer>(
//            _ store: Store<Red>,
//            _ request: Red.Request?
//        ) async {
//            if let request = request {
//                await store.send(request)
//            }
//        }
//
//        await withTaskGroup(of: Void.self) { group in
//            repeat group.addTask {
//                await sendToStore(each stores, each mappedRequests)
//            }
//        }
//    }
//
//    private func observeStores() {
//        for store in repeat each stores {
//            observe(store)
//        }
//    }
//
//    private func observe<Red: Reducer>(_ store: Store<Red>) {
//        withObservationTracking {
//            _ = store.state
//        } onChange: {
//            Task { @MainActor [weak self] in
//                self?.updateState()
//                self?.observe(store)
//            }
//        }
//    }
//
//    private func updateState() {
//        let currentStates = (repeat (each stores).state)
//        self.state = reducer.mapState(stores: currentStates)
//    }
//}
