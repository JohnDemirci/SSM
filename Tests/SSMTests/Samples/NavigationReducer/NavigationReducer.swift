//
//  NavigationReducer.swift
//  SSM
//
//  Created by John Demirci on 7/28/25.
//

import LoadableValues
import SSM
import Foundation

struct NavigationReducer: Reducer {
    typealias Environment = Void
    enum Destination: Hashable, Identifiable {
        case view1
        case view2

        var id: AnyHashable { self }
    }

    enum Request {
        case push(Destination)
        case pop
    }

    struct State {
        var destination: Destination?
    }

    func reduce(store: Store<NavigationReducer>, request: Request) async {
        switch request {
        case .push(let destination):
            modifyValue(store: store, \.destination) {
                $0 = destination
            }

        case .pop:
            modifyValue(store: store, \.destination) {
                $0 = nil
            }
        }
    }
}

extension StoreContrainer {
    func navigationStore() -> Store<NavigationReducer> {
        store(
            type: Store<NavigationReducer>.self,
            state: NavigationReducer.State()
        )
    }
}
