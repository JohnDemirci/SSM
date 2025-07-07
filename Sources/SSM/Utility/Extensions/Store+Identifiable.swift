import Foundation

extension Store: @MainActor Identifiable {
    public var id: ReferenceIdentifier {
        getID()
    }

    private func getID() -> ReferenceIdentifier where R.State: Identifiable {
        ReferenceIdentifier(id: state.id as AnyHashable)
    }

    private func getID() -> ReferenceIdentifier {
        ReferenceIdentifier(id: ObjectIdentifier(Self.self) as AnyHashable)
    }
}
