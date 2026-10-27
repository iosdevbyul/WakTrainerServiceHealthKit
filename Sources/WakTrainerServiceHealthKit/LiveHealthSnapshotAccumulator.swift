import Foundation
import WakTrainerCoreModels

/// Reconciles HealthKit anchored-query inserts and deletions by sample UUID.
/// Sample end times are acquisition instants, never callback or upload times.
struct LiveHealthSnapshotAccumulator {
    private struct Entry {
        let metric: WorkoutHealthMetric
        let value: Double
        let sampleEndDate: Date
    }

    private var entries: [UUID: Entry] = [:]

    /// Stable HealthKit UUIDs make repeated anchored callbacks idempotent.
    mutating func apply(
        sampleID: UUID,
        metric: WorkoutHealthMetric,
        value: Double,
        sampleEndDate: Date
    ) {
        guard Self.supportedMetrics.contains(metric) else { return }
        entries[sampleID] = Entry(
            metric: metric,
            value: value,
            sampleEndDate: sampleEndDate
        )
    }

    /// Backward-compatible internal helper for independently acquired samples.
    mutating func apply(
        metric: WorkoutHealthMetric,
        value: Double,
        sampleEndDate: Date
    ) {
        apply(
            sampleID: UUID(),
            metric: metric,
            value: value,
            sampleEndDate: sampleEndDate
        )
    }

    mutating func remove(sampleID: UUID) {
        entries.removeValue(forKey: sampleID)
    }

    private static let supportedMetrics: Set<WorkoutHealthMetric> = [
        .heartRate, .activeEnergyBurned, .stepCount,
        .distanceWalkingRunning, .distanceCycling
    ]

    var snapshot: HealthSnapshot {
        var latestDates: [WorkoutHealthMetric: Date] = [:]
        var heartRate: Double = 0
        var latestHeartRate: (date: Date, id: UUID)?
        var calories: Double = 0
        var steps: Double = 0
        var distance: Double = 0

        for (id, entry) in entries {
            if let previous = latestDates[entry.metric] {
                if entry.sampleEndDate > previous {
                    latestDates[entry.metric] = entry.sampleEndDate
                }
            } else {
                latestDates[entry.metric] = entry.sampleEndDate
            }

            switch entry.metric {
            case .heartRate:
                if let latest = latestHeartRate {
                    if entry.sampleEndDate > latest.date ||
                        (entry.sampleEndDate == latest.date &&
                         id.uuidString > latest.id.uuidString) {
                        heartRate = entry.value
                        latestHeartRate = (entry.sampleEndDate, id)
                    }
                } else {
                    heartRate = entry.value
                    latestHeartRate = (entry.sampleEndDate, id)
                }
            case .activeEnergyBurned:
                calories += entry.value
            case .stepCount:
                steps += entry.value
            case .distanceWalkingRunning, .distanceCycling:
                distance += entry.value
            default:
                break
            }
        }

        return HealthSnapshot(
            heartRate: heartRate,
            stepCount: steps,
            activeCalories: calories,
            distance: distance,
            sampleEndDates: latestDates
        )
    }
}
