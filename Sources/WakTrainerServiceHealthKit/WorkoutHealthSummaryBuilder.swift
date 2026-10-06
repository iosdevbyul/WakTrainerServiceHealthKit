import Foundation
import WakTrainerCoreModels

enum WorkoutHealthSummaryBuilder {

    static func makeSummary(
        from samples: [WorkoutHealthMetricSample]
    ) -> WorkoutHealthSummary {
        let heartRates = values(
            for: [.heartRate],
            in: samples
        )

        let heartRateVariability = values(
            for: [.heartRateVariabilitySDNN],
            in: samples
        )

        let heartRateRecovery = values(
            for: [.heartRateRecoveryOneMinute],
            in: samples
        )

        let speeds = samples.filter {
            $0.metric == .runningSpeed ||
            $0.metric == .cyclingSpeed
        }

        let cadences = samples.filter {
            $0.metric == .runningCadence ||
            $0.metric == .cyclingCadence
        }

        let powers = samples.filter {
            $0.metric == .runningPower ||
            $0.metric == .cyclingPower
        }

        return WorkoutHealthSummary(
            averageHeartRate: average(heartRates),
            minimumHeartRate: heartRates.min(),
            maximumHeartRate: heartRates.max(),
            averageHeartRateVariability: average(heartRateVariability),
            heartRateRecoveryOneMinute: heartRateRecovery.last,
            activeCalories: sum(
                for: [.activeEnergyBurned],
                in: samples
            ),
            basalCalories: sum(
                for: [.basalEnergyBurned],
                in: samples
            ),
            stepCount: sum(
                for: [.stepCount],
                in: samples
            ),
            distanceMeters: sum(
                for: [
                    .distanceWalkingRunning,
                    .distanceCycling,
                    .distanceSwimming
                ],
                in: samples
            ),
            swimmingStrokeCount: sum(
                for: [.swimmingStrokeCount],
                in: samples
            ),
            averageSpeedMetersPerSecond: weightedAverage(speeds),
            maximumSpeedMetersPerSecond: speeds.map(\.value).max(),
            averageCadence: weightedAverage(cadences),
            averagePowerWatts: weightedAverage(powers),
            averageOxygenSaturation: average(
                values(
                    for: [.oxygenSaturation],
                    in: samples
                )
            ),
            averageRespiratoryRate: average(
                values(
                    for: [.respiratoryRate],
                    in: samples
                )
            ),
            vo2Max: values(
                for: [.vo2Max],
                in: samples
            ).last,
            elevationGainMeters: nil
        )
    }
}

private extension WorkoutHealthSummaryBuilder {

    static func values(
        for metrics: Set<WorkoutHealthMetric>,
        in samples: [WorkoutHealthMetricSample]
    ) -> [Double] {
        samples.compactMap { sample in
            metrics.contains(sample.metric)
                ? sample.value
                : nil
        }
    }

    static func sum(
        for metrics: Set<WorkoutHealthMetric>,
        in samples: [WorkoutHealthMetricSample]
    ) -> Double? {
        let matched = values(
            for: metrics,
            in: samples
        )

        guard !matched.isEmpty else {
            return nil
        }

        return matched.reduce(0, +)
    }

    static func average(
        _ values: [Double]
    ) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    static func weightedAverage(
        _ samples: [WorkoutHealthMetricSample]
    ) -> Double? {
        guard !samples.isEmpty else {
            return nil
        }

        var weightedTotal: Double = 0
        var totalWeight: Double = 0

        for sample in samples {
            let duration = sample.endDate
                .timeIntervalSince(sample.startDate)

            let weight = duration > 0
                ? duration
                : 1

            weightedTotal += sample.value * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            return nil
        }

        return weightedTotal / totalWeight
    }
}
