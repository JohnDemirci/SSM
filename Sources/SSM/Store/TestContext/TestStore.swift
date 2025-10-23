//
//  TestStore.swift
//  SSM
//
//  Created by John on 10/22/25.
//

import Foundation
import Observation

#if DEBUG
@MainActor
@Observable
public final class TestStore<R: Reducer>: Identifiable {
    public typealias State = R.State
    public typealias Request = R.Request
    
    weak var store: Store<R>?
    public let id: ReferenceIdentifier
    
    init(
        _ store: Store<R>
    ) {
        self.store = store
        self.id = store.id
    }
    
    func send(_ request: Request) async {
        await store?.send(request)
    }
    
    func send(_ request: Request) {
        store?.send(request)
    }
}
#endif
