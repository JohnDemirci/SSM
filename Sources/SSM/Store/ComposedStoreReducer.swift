import Foundation

public protocol ComposedStoreReducer {
    associatedtype State
    associatedtype Request

    func mapState<each R: Reducer>(stores: repeat Store<each R>,) -> State
    
    func mapRequest<each R: Reducer>(
        _ request: Request,
        stores: repeat Store<each R>
    ) -> (repeat Store<each R>.Request?)

    func send<each R: Reducer>(_ request: Request?, to store: repeat Store<each R>)
    func send<each R: Reducer>(_ request: Request?, to store: repeat Store<each R>) async

    func observe<each R: Reducer, each V>() -> (repeat KeyPath<Store<each R>.State, each V>)

    init()
}
