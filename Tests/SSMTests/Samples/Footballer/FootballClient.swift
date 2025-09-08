//
//  FootballerClient.swift
//  SSM
//
//  Created by John Demirci on 9/3/25.
//

import Foundation

actor FootballClient {
    func fetchFootballers() async throws -> [Footballer] {
        return [.bukayoSaka]
    }

    @discardableResult
    func registerFootballer(_ footballer: Footballer) async throws -> EquatableVoid {
        return EquatableVoid()
    }
}

extension FootballClient {
    func raiseError(_ error: Error) -> FootballClient {
        return self
    }

    func expectResult<T>(_ result: T) -> FootballClient {
        return self
    }
}
