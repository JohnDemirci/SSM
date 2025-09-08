//
//  Footballer.swift
//  SSM
//
//  Created by John Demirci on 9/3/25.
//

import Foundation

struct Footballer: Hashable, Equatable, Identifiable {
    let name: String
    let lastName: String
    let age: Int
    let team: String
    let goals: Int
    let assists: Int
    let position: Position

    var id: AnyHashable {
        self as AnyHashable
    }
}

extension Footballer {
    static let ravidRaya: Footballer = .init(
        name: "David",
        lastName: "Raya",
        age: 27,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .gk
    )

    static let jurrienTimber: Footballer = .init(
        name: "Jurrien",
        lastName: "Timber",
        age: 23,
        team: "Arsenal",
        goals: 2,
        assists: 1,
        position: .rb
    )

    static let williamSaliba: Footballer = .init(
        name: "William",
        lastName: "Saliba",
        age: 22,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .cb
    )

    static let gabrielMaghaeles: Footballer = .init(
        name: "Gabriel",
        lastName: "Maghaeles",
        age: 26,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .cb
    )

    static let riccardoCalafiori: Footballer = .init(
        name: "Riccardo",
        lastName: "Calafiori",
        age: 23,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .lb
    )

    static let martinZubimendi: Footballer = .init(
        name: "Martin",
        lastName: "Zubimendi",
        age: 26,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .cdm
    )

    static let declanRice: Footballer = .init(
        name: "Declan",
        lastName: "Rice",
        age: 25,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .lcm
    )

    static let martinOdegaard: Footballer = .init(
        name: "Martin",
        lastName: "Ødegaard",
        age: 24,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .rcm
    )

    static let bukayoSaka: Footballer = .init(
        name: "Bukayo",
        lastName: "Saka",
        age: 23,
        team: "Arsenal",
        goals: 1,
        assists: 0,
        position: .amr
    )

    static let eberechiEze: Footballer = .init(
        name: "Eberechi",
        lastName: "Eze",
        age: 24,
        team: "Arsenal",
        goals: 0,
        assists: 0,
        position: .aml
    )

    static let viktorGyokeres: Footballer = .init(
        name: "Viktor",
        lastName: "Gyökeres",
        age: 27,
        team: "Arsenal",
        goals: 2,
        assists: 0,
        position: .st
    )
}

enum Position: Hashable, Equatable {
    case gk
    case rb
    case cb
    case lb
    case rwb
    case lwb
    case cdm
    case rcm
    case lcm
    case amr
    case amc
    case aml
    case st
}
