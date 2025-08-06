import Foundation

/// A type-erased, hashable identifier suitable for uniquely referencing values.
///
/// `ReferenceIdentifier` encapsulates an identifier of any hashable type, allowing
/// flexible and efficient storage and comparison of unique references across a codebase.
/// It is useful for situations where you need to refer to objects or values without exposing
/// their concrete identifier types. 
///
/// - Conforms to:
///   - `Identifiable`: exposes an `id` property of type `AnyHashable`.
///   - `Hashable`: can be used as a dictionary key or inserted into a set.
///   - `@unchecked Sendable`: can be shared across concurrency domains; thread safety is not guaranteed by the type itself.
///
/// Example usage:
/// ```swift
/// let ref1 = ReferenceIdentifier(id: UUID())
/// let ref2 = ReferenceIdentifier(id: "my-string-id")
/// ```
public final class ReferenceIdentifier: Identifiable, Hashable, @unchecked Sendable {
    public let id: AnyHashable

    init(id: AnyHashable) {
        self.id = id
    }

    public static func == (lhs: ReferenceIdentifier, rhs: ReferenceIdentifier) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
