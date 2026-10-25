import Foundation
import Testing

@testable import WakTrainerServiceHealthKit

@Suite("Live observation session isolation")
struct LiveObservationSessionTests {
    @Test("Old stream termination cannot invalidate a newer session")
    func staleTerminationDoesNotStopReplacement() {
        var sessions = LiveObservationSession()
        let oldID = sessions.begin()
        let newID = sessions.begin()

        #expect(oldID != newID)
        #expect(!sessions.isCurrent(oldID))
        #expect(sessions.isCurrent(newID))
        #expect(!sessions.end(ifCurrent: oldID))
        #expect(sessions.isCurrent(newID))
    }

    @Test("Stopped sessions reject delayed anchored-query callbacks")
    func stoppedSessionIsNotCurrent() {
        var sessions = LiveObservationSession()
        let sessionID = sessions.begin()

        #expect(sessions.isCurrent(sessionID))
        #expect(sessions.end(ifCurrent: sessionID))
        #expect(!sessions.isCurrent(sessionID))
        #expect(!sessions.end(ifCurrent: sessionID))
    }

    @Test("Repeated workout starts create distinct observation identities")
    func restartedSessionHasNewIdentity() {
        var sessions = LiveObservationSession()
        let firstID = sessions.begin()
        #expect(sessions.end(ifCurrent: firstID))
        let secondID = sessions.begin()

        #expect(!sessions.isCurrent(firstID))
        #expect(sessions.isCurrent(secondID))
    }
}
