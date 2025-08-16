//
//  Broadcast.swift
//  SSM
//
//  Created by John Demirci on 7/13/25.
//

import AsyncAlgorithms
import Foundation

@MainActor
final class BroadcastStudio {
    static let shared = BroadcastStudio()

    private var continuation: AsyncStream<any BroadcastMessage>.Continuation?
    private(set) lazy var channel: AsyncStream<any BroadcastMessage> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    func publish<M: BroadcastMessage>(_ message: M) {
        continuation?.yield(message)
    }

    deinit {
        continuation?.finish()
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
public protocol BroadcastMessage: Sendable, Identifiable, Hashable {
    var id: UUID { get }
    var name: String { get }
}
