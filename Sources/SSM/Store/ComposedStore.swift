import Foundation

@MainActor
@Observable
final class ComposedStore<
    CR: ComposedStoreReducer & Sendable,
    each R: Reducer
> {
    private let reducer: CR
    private let stores: (repeat Store<each R>)
 //   private let keypaths: (repeat KeyPath<(each R).State, Any> & Sendable)

    public private(set) var state: CR.State

    init(
        reducer: CR = .init(),
        stores: (repeat Store<each R>)
    ) {
        self.reducer = reducer
        self.stores = stores

        state = reducer.mapState(
            stores: repeat each stores,
        )

        setupObservation()
    }

    func observe<T>(_ store: Store<T>) {
        withObservationTracking {
            _ = store.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateState()
                self?.observe(store)
            }
        }
    }

    private func setupObservation() {
        // We need to manually pair each store with its keypath
        // This is a limitation of parameter packs - we can't zip them easily
        repeat observe(each stores)
    }

    private func updateState() {
        state = reducer.mapState(
            stores: repeat each stores
        )
    }

    public func send(_ request: CR.Request) {
        Task { @MainActor in
            await reducer.send(request, to: repeat each stores)
        }
    }

    public func send(_ request: sending CR.Request) async {
        await reducer.send(request, to: repeat each stores)
    }
}

