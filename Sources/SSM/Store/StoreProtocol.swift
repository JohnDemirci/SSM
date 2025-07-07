import Foundation

public protocol StoreProtocol {
    associatedtype State
    associatedtype Request
    associatedtype Environment: Sendable

    var state: State { get }
    func send(_ request: sending Request) async
    func send(_ request: sending Request)
}
