import Foundation

@Observable
final class BoxedState<R: Reducer, T> {
    private let store: StoreOf<R>
    private let keyPath: KeyPath<StoreOf<R>.State, T>

    @MainActor
    @ObservationTracked
    var value: T { store.state[keyPath: keyPath] }

    init(of keyPath: KeyPath<StoreOf<R>.State, T>, in store: StoreOf<R>) {
        self.store = store
        self.keyPath = keyPath
    }
}
