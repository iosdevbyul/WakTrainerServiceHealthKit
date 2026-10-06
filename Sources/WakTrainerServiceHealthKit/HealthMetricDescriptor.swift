import Foundation
import HealthKit
import WakTrainerCoreModels

struct HealthMetricDescriptor: @unchecked Sendable {
    let metric: WorkoutHealthMetric
    let identifier: HKQuantityTypeIdentifier
    let unit: HKUnit
    let unitSymbol: String

    var quantityType: HKQuantityType? {
        HKObjectType.quantityType(
            forIdentifier: identifier
        )
    }

    func queryRange(
        workoutStartDate: Date,
        workoutEndDate: Date
    ) -> ClosedRange<Date> {
        switch metric {
        case .heartRateRecoveryOneMinute:
            return workoutEndDate.addingTimeInterval(-30)
                ... workoutEndDate.addingTimeInterval(120)
        default:
            return workoutStartDate ... workoutEndDate
        }
    }

    func value(
        from sample: HKQuantitySample
    ) -> Double {
        let rawValue = sample.quantity.doubleValue(
            for: unit
        )

        if metric == .oxygenSaturation {
            return rawValue * 100
        }

        return rawValue
    }
}

extension HealthMetricDescriptor {

    static let all: [HealthMetricDescriptor] = [
        HealthMetricDescriptor(
            metric: .heartRate,
            identifier: .heartRate,
            unit: HKUnit(from: "count/min"),
            unitSymbol: "bpm"
        ),
        HealthMetricDescriptor(
            metric: .heartRateVariabilitySDNN,
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            unitSymbol: "ms"
        ),
        HealthMetricDescriptor(
            metric: .heartRateRecoveryOneMinute,
            identifier: .heartRateRecoveryOneMinute,
            unit: HKUnit(from: "count/min"),
            unitSymbol: "bpm"
        ),
        HealthMetricDescriptor(
            metric: .activeEnergyBurned,
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            unitSymbol: "kcal"
        ),
        HealthMetricDescriptor(
            metric: .basalEnergyBurned,
            identifier: .basalEnergyBurned,
            unit: .kilocalorie(),
            unitSymbol: "kcal"
        ),
        HealthMetricDescriptor(
            metric: .stepCount,
            identifier: .stepCount,
            unit: .count(),
            unitSymbol: "count"
        ),
        HealthMetricDescriptor(
            metric: .distanceWalkingRunning,
            identifier: .distanceWalkingRunning,
            unit: .meter(),
            unitSymbol: "m"
        ),
        HealthMetricDescriptor(
            metric: .distanceCycling,
            identifier: .distanceCycling,
            unit: .meter(),
            unitSymbol: "m"
        ),
        HealthMetricDescriptor(
            metric: .distanceSwimming,
            identifier: .distanceSwimming,
            unit: .meter(),
            unitSymbol: "m"
        ),
        HealthMetricDescriptor(
            metric: .swimmingStrokeCount,
            identifier: .swimmingStrokeCount,
            unit: .count(),
            unitSymbol: "count"
        ),
        HealthMetricDescriptor(
            metric: .flightsClimbed,
            identifier: .flightsClimbed,
            unit: .count(),
            unitSymbol: "count"
        ),
        HealthMetricDescriptor(
            metric: .runningSpeed,
            identifier: .runningSpeed,
            unit: HKUnit.meter()
                .unitDivided(by: .second()),
            unitSymbol: "m/s"
        ),
        HealthMetricDescriptor(
            metric: .runningPower,
            identifier: .runningPower,
            unit: .watt(),
            unitSymbol: "W"
        ),
        HealthMetricDescriptor(
            metric: .runningStrideLength,
            identifier: .runningStrideLength,
            unit: .meter(),
            unitSymbol: "m"
        ),
        HealthMetricDescriptor(
            metric: .runningVerticalOscillation,
            identifier: .runningVerticalOscillation,
            unit: .meter(),
            unitSymbol: "m"
        ),
        HealthMetricDescriptor(
            metric: .runningGroundContactTime,
            identifier: .runningGroundContactTime,
            unit: .secondUnit(with: .milli),
            unitSymbol: "ms"
        ),
        HealthMetricDescriptor(
            metric: .cyclingSpeed,
            identifier: .cyclingSpeed,
            unit: HKUnit.meter()
                .unitDivided(by: .second()),
            unitSymbol: "m/s"
        ),
        HealthMetricDescriptor(
            metric: .cyclingPower,
            identifier: .cyclingPower,
            unit: .watt(),
            unitSymbol: "W"
        ),
        HealthMetricDescriptor(
            metric: .cyclingCadence,
            identifier: .cyclingCadence,
            unit: HKUnit(from: "count/min"),
            unitSymbol: "rpm"
        ),
        HealthMetricDescriptor(
            metric: .oxygenSaturation,
            identifier: .oxygenSaturation,
            unit: .percent(),
            unitSymbol: "%"
        ),
        HealthMetricDescriptor(
            metric: .respiratoryRate,
            identifier: .respiratoryRate,
            unit: HKUnit(from: "count/min"),
            unitSymbol: "breaths/min"
        ),
        HealthMetricDescriptor(
            metric: .vo2Max,
            identifier: .vo2Max,
            unit: HKUnit(from: "ml/kg*min"),
            unitSymbol: "mL/kg/min"
        )
    ]

    static let liveHeartRate = HealthMetricDescriptor(
        metric: .heartRate,
        identifier: .heartRate,
        unit: HKUnit(from: "count/min"),
        unitSymbol: "bpm"
    )

    static let liveActiveEnergy = HealthMetricDescriptor(
        metric: .activeEnergyBurned,
        identifier: .activeEnergyBurned,
        unit: .kilocalorie(),
        unitSymbol: "kcal"
    )

    static let liveStepCount = HealthMetricDescriptor(
        metric: .stepCount,
        identifier: .stepCount,
        unit: .count(),
        unitSymbol: "count"
    )

    static let liveDistance = HealthMetricDescriptor(
        metric: .distanceWalkingRunning,
        identifier: .distanceWalkingRunning,
        unit: .meter(),
        unitSymbol: "m"
    )
}
