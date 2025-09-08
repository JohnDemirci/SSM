//
//  Subscription.swift
//  SSM
//
//  Created by John Demirci on 9/3/25.
//

import Combine
import Foundation

public protocol Subscription {
    associatedtype R: Reducer

    var subscriptionType: SubscriptionType<R.Request> { get }
}

public enum SubscriptionType<Request> {
    case publisher(AnyPublisher<Request, Never>)
    case stream(AsyncStream<Request>)
}
