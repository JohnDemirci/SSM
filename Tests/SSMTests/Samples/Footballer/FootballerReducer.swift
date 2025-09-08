//
//  FootballerReducer.swift
//  SSM
//
//  Created by John Demirci on 9/3/25.
//

import SSM

public struct EquatableVoid: Hashable, Sendable, Codable {}

struct FootballerReducer: Reducer {
    struct State {
        var footballers: LoadableValue<[Footballer], Error> = .idle
        var registerFootballer: LoadableValue<EquatableVoid, Error> = .idle
    }

    enum Request {
        case fetchFootballers
        case registerFootballer(Footballer)
    }

    struct Environment {
        let footballClient: FootballClient
        let broadcast: BroadcastStudio
    }

    func reduce(store: Store<FootballerReducer>, request: Request) async {
        switch request {
        case .fetchFootballers:
            await load(
                store: store,
                keyPath: \.footballers,
                work: { environment in
                    try await environment.footballClient.fetchFootballers()
                }
            )

        case .registerFootballer(let footballer):
            await load(
                store: store,
                keyPath: \.registerFootballer,
                work: {
                    try await $0.footballClient.registerFootballer(footballer)
                }
            )

            guard case .loaded = store.registerFootballer else { return }

            broadcast(
                FootballerCreatedMessage(
                    footballer: footballer,
                    originatingFrom: store
                )
            )
        }
    }

    func setupSubscriptions(store: Store<FootballerReducer>) {
        subscribe(
            store: store,
            keypath: \.broadcast) { dependency in
                dependency.publisher
            } map: { message in
                switch message {
                case is FootballerCreatedMessage:
                    return .fetchFootballers
                default:
                    return nil
                }
            }
    }
}

extension FootballerReducer {
    struct FootballerCreatedMessage: BroadcastMessage {
        var name: String { "Footballer created" }

        let footballer: Footballer
        let originatingFrom: any StoreProtocol

        var id: AnyHashable {
            footballer.id
        }
    }
}
