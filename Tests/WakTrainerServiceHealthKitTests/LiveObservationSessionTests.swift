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
        let endedOld = sessions.end(ifCurrent: oldID)
        #expect(!endedOld)
        #expect(sessions.isCurrent(newID))
    }

    @Test("Stopped sessions reject delayed anchored-query callbacks")
    func stoppedSessionIsNotCurrent() {
        var sessions = LiveObservationSession()
        let sessionID = sessions.begin()

        #expect(sessions.isCurrent(sessionID))
        let ended = sessions.end(ifCurrent: sessionID)
        #expect(ended)
        #expect(!sessions.isCurrent(sessionID))
        let endedAgain = sessions.end(ifCurrent: sessionID)
        #expect(!endedAgain)
    }

    @Test("Repeated workout starts create distinct observation identities")
    func restartedSessionHasNewIdentity() {
        var sessions = LiveObservationSession()
        let firstID = sessions.begin()
        let endedFirst = sessions.end(ifCurrent: firstID)
        #expect(endedFirst)
        let secondID = sessions.begin()

        #expect(!sessions.isCurrent(firstID))
        #expect(sessions.isCurrent(secondID))
    }
}
