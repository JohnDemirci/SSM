//
//  Broadcast.swift
//  SSM
//
//  Created by John Demirci on 7/13/25.
//

import Combine
import Foundation

public protocol BroadcastHubPublishable {
    var publisher: AnyPublisher<any BroadcastMessage, Never> { get }
}

protocol BroadcastMessagePublishable {
    @MainActor
    func publish<M: BroadcastMessage>(_ message: M)
}

protocol Broadcasting: BroadcastHubPublishable, BroadcastMessagePublishable {}

public final class BroadcastStudio: Broadcasting, Sendable {
    public static let shared = BroadcastStudio()

    private init() {}

    nonisolated(unsafe)
    private let subject = PassthroughSubject<any BroadcastMessage, Never>()

    public var publisher: AnyPublisher<any BroadcastMessage, Never> {
        subject.eraseToAnyPublisher()
    }

    @MainActor
    func publish<M: BroadcastMessage>(_ message: M) {
        subject.send(message)
    }
}

/// A protocol representing a message that can be broadcast within an application.
///
/// Conforming types must be `Sendable`, `Identifiable`, and `Hashable`.
/// Each broadcast message has a stable `UUID` identifier and a descriptive `name`.
///
/// Types that conform to `BroadcastMessage` can be sent via `BroadcastStudio` to notify
/// multiple subscribers of an event or data update. This pattern is suitable for loosely-coupled
/// communication between different parts of an app (such as cross-scene or cross-module notifications).
///
/// - Note: The `id` property provides a unique identifier for the message instance,
///   while `name` offers a human-readable or semantic message type description.
///
/// Example:
/// ```swift
/// struct UserDidLogin: BroadcastMessage {
///     let id = UUID()
///     let name = "UserDidLogin"
///     let userID: String
/// }
/// ```
public protocol BroadcastMessage: Sendable, Identifiable {
    var name: String { get }
    var originatingFrom: any StoreProtocol { get }
}
