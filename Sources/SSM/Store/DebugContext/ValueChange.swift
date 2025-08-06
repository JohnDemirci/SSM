//
//  ValueChange.swift
//  SSM
//
//  Created by John Demirci on 7/30/25.
//

#if DEBUG
import Foundation
import LoadableValues

public struct ValueChange<R: Reducer> {
    public let keypath: PartialKeyPath<R.State>
    public let date: Date
    public let previousValue: Any
    public let newValue: Any

    public var debugDescription: String {
        """
        Store<\(R.self)> has changed its
        Value: \(keypath)
        From: \(previousValue)
        To: \(newValue)
        At: \(date)
        """
    }
}

#endif
