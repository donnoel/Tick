import Foundation

nonisolated protocol TickKeyValueStore: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
    @discardableResult
    func synchronize() -> Bool
}

nonisolated extension NSUbiquitousKeyValueStore: TickKeyValueStore {}
