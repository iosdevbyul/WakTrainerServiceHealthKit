import Foundation
import Testing
import WakTrainerCoreModels

@testable import WakTrainerServiceHealthKit

@Suite("Live HealthKit acquisition timestamps")
struct LiveHealthSnapshotAccumulatorTests {
    @Test("Heart rate retains newest acquisition instant when callbacks arrive out of order")
    func lateHeartRateDoesNotReplaceNewerReading() {
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        let second = first.addingTimeInterval(10)
        var accumulator = LiveHealthSnapshotAccumulator()

        accumulator.apply(metric: .heartRate, value: 150, sampleEndDate: second)
        accumulator.apply(metric: .heartRate, value: 100, sampleEndDate: first)

        #expect(accumulator.snapshot.heartRate == 150)
        #expect(accumulator.snapshot.sampleEndDates[.heartRate] == second)
    }

    @Test("Cumulative metrics sum samples but keep latest contributing sample time")
    func aggregateMetricsRetainLatestSampleTime() {
        let early = Date(timeIntervalSince1970: 1_800_000_000)
        let late = early.addingTimeInterval(120)
        var accumulator = LiveHealthSnapshotAccumulator()

        accumulator.apply(metric: .stepCount, value: 50, sampleEndDate: late)
        accumulator.apply(metric: .stepCount, value: 25, sampleEndDate: early)
        accumulator.apply(metric: .activeEnergyBurned, value: 10, sampleEndDate: early)
        accumulator.apply(metric: .activeEnergyBurned, value: 15, sampleEndDate: late)
        accumulator.apply(metric: .distanceWalkingRunning, value: 100, sampleEndDate: early)

        let snapshot = accumulator.snapshot
        #expect(snapshot.stepCount == 75)
        #expect(snapshot.activeCalories == 25)
        #expect(snapshot.distance == 100)
        #expect(snapshot.sampleEndDates[.stepCount] == late)
        #expect(snapshot.sampleEndDates[.activeEnergyBurned] == late)
        #expect(snapshot.sampleEndDates[.distanceWalkingRunning] == early)
        #expect(snapshot.sampleEndDates[.heartRate] == nil)
    }

    @Test("Reset clears live values and timestamps together")
    func resetRemovesOldMeasurementMetadata() {
        let measuredAt = Date(timeIntervalSince1970: 1_800_000_000)
        var accumulator = LiveHealthSnapshotAccumulator()
        accumulator.apply(metric: .heartRate, value: 140, sampleEndDate: measuredAt)

        accumulator = LiveHealthSnapshotAccumulator()

        #expect(accumulator.snapshot.heartRate == 0)
        #expect(accumulator.snapshot.sampleEndDates.isEmpty)
    }
}
