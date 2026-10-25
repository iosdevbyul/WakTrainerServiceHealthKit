import Foundation
import WakTrainerCoreModels

/// Maintains original HealthKit acquisition times separately from delivery time.
/// Accumulated metrics keep their totals; timestamps are the latest contributing
/// sample end time. A delayed heart-rate sample must not replace a newer value.
struct LiveHealthSnapshotAccumulator {
    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0
    private(set) var stepCount: Double = 0
    private(set) var distance: Double = 0
    private(set) var sampleEndDates: [WorkoutHealthMetric: Date] = [:]

    mutating func apply(
        metric: WorkoutHealthMetric,
        value: Double,
        sampleEndDate: Date
    ) {
        let previous = sampleEndDates[metric]

        switch metric {
        case .heartRate:
            guard previous == nil || sampleEndDate >= previous! else {
                return
            }
            heartRate = value

        case .activeEnergyBurned:
            activeCalories += value

        case .stepCount:
            stepCount += value

        case .distanceWalkingRunning:
            distance += value

        default:
            return
        }

        if previous == nil || sampleEndDate > previous! {
            sampleEndDates[metric] = sampleEndDate
        }
    }

    var snapshot: HealthSnapshot {
        HealthSnapshot(
            heartRate: heartRate,
            stepCount: stepCount,
            activeCalories: activeCalories,
            distance: distance,
            sampleEndDates: sampleEndDates
        )
    }
}
