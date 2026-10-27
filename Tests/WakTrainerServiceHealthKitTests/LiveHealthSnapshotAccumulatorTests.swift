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

    @Test("Cycling distance is observed and repeated anchored samples are not double counted")
    func cyclingDistanceIsIncludedOnce() {
        let sampleID = UUID()
        let acquiredAt = Date(timeIntervalSince1970: 1_800_000_000)
        var accumulator = LiveHealthSnapshotAccumulator()
        accumulator.apply(
            sampleID: sampleID,
            metric: .distanceCycling,
            value: 1_250,
            sampleEndDate: acquiredAt
        )
        accumulator.apply(
            sampleID: sampleID,
            metric: .distanceCycling,
            value: 1_250,
            sampleEndDate: acquiredAt
        )
        #expect(accumulator.snapshot.distance == 1_250)
        #expect(accumulator.snapshot.sampleEndDates[.distanceCycling] == acquiredAt)
        accumulator.remove(sampleID: sampleID)
        #expect(accumulator.snapshot.distance == 0)
        #expect(accumulator.snapshot.sampleEndDates[.distanceCycling] == nil)
    }

    @Test("Repeated anchored sample UUID does not double-count cumulative metrics")
    func repeatedSamplesAreIdempotent() {
        let id = UUID()
        let acquiredAt = Date(timeIntervalSince1970: 1_800_000_000)
        var accumulator = LiveHealthSnapshotAccumulator()
        accumulator.apply(
            sampleID: id, metric: .stepCount, value: 120,
            sampleEndDate: acquiredAt
        )
        accumulator.apply(
            sampleID: id, metric: .stepCount, value: 120,
            sampleEndDate: acquiredAt
        )

        #expect(accumulator.snapshot.stepCount == 120)
        #expect(accumulator.snapshot.sampleEndDates[.stepCount] == acquiredAt)
    }

    @Test("Deletion subtracts cumulative sample and recalculates latest acquisition time")
    func deletedSampleIsRemovedFromTotalsAndMetadata() {
        let firstID = UUID()
        let secondID = UUID()
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        let second = first.addingTimeInterval(60)
        var accumulator = LiveHealthSnapshotAccumulator()
        accumulator.apply(
            sampleID: firstID, metric: .activeEnergyBurned, value: 10,
            sampleEndDate: first
        )
        accumulator.apply(
            sampleID: secondID, metric: .activeEnergyBurned, value: 20,
            sampleEndDate: second
        )
        accumulator.remove(sampleID: secondID)

        #expect(accumulator.snapshot.activeCalories == 10)
        #expect(accumulator.snapshot.sampleEndDates[.activeEnergyBurned] == first)

        accumulator.remove(sampleID: firstID)
        #expect(accumulator.snapshot.activeCalories == 0)
        #expect(accumulator.snapshot.sampleEndDates[.activeEnergyBurned] == nil)
    }

    @Test("Deleting latest heart rate restores previous original sample")
    func deletingLatestHeartRateRestoresPrevious() {
        let olderID = UUID()
        let newerID = UUID()
        let earlier = Date(timeIntervalSince1970: 1_800_000_000)
        let later = earlier.addingTimeInterval(30)
        var accumulator = LiveHealthSnapshotAccumulator()
        accumulator.apply(
            sampleID: newerID, metric: .heartRate, value: 145,
            sampleEndDate: later
        )
        accumulator.apply(
            sampleID: olderID, metric: .heartRate, value: 110,
            sampleEndDate: earlier
        )
        accumulator.remove(sampleID: newerID)

        #expect(accumulator.snapshot.heartRate == 110)
        #expect(accumulator.snapshot.sampleEndDates[.heartRate] == earlier)
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
