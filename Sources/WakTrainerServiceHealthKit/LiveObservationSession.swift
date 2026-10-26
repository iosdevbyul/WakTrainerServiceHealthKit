import Foundation

/// Session identity for asynchronous anchored-query callbacks and stream termination.
/// A callback from a previous session must not mutate the current observation.
struct LiveObservationSession {
    private(set) var currentID: UUID?

    @discardableResult
    mutating func begin() -> UUID {
        let id = UUID()
        currentID = id
        return id
    }

    func isCurrent(_ id: UUID) -> Bool {
        currentID == id
    }

    @discardableResult
    mutating func end(ifCurrent id: UUID) -> Bool {
        guard currentID == id else { return false }
        currentID = nil
        return true
    }
}
