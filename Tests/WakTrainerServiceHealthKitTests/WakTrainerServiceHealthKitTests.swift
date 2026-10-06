import Foundation
import HealthKit
import Testing
import WakTrainerCoreModels

@testable import WakTrainerServiceHealthKit

@Suite("WakTrainerServiceHealthKit")
struct WakTrainerServiceHealthKitTests {

    @Test("운동 건강 요약은 원본 샘플로부터 계산된다")
    func healthSummaryIsBuiltFromSamples() {
        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let samples = [
            sample(
                metric: .heartRate,
                start: start,
                value: 100,
                unit: "bpm"
            ),
            sample(
                metric: .heartRate,
                start: start.addingTimeInterval(5),
                value: 140,
                unit: "bpm"
            ),
            sample(
                metric: .heartRateVariabilitySDNN,
                start: start,
                value: 42,
                unit: "ms"
            ),
            sample(
                metric: .heartRateRecoveryOneMinute,
                start: start,
                value: 28,
                unit: "bpm"
            ),
            sample(
                metric: .activeEnergyBurned,
                start: start,
                value: 120,
                unit: "kcal"
            ),
            sample(
                metric: .activeEnergyBurned,
                start: start,
                value: 80,
                unit: "kcal"
            ),
            sample(
                metric: .stepCount,
                start: start,
                value: 1000,
                unit: "count"
            ),
            sample(
                metric: .distanceWalkingRunning,
                start: start,
                value: 2400,
                unit: "m"
            ),
            sample(
                metric: .distanceCycling,
                start: start,
                value: 5000,
                unit: "m"
            ),
            sample(
                metric: .cyclingSpeed,
                start: start,
                duration: 10,
                value: 5,
                unit: "m/s"
            ),
            sample(
                metric: .cyclingSpeed,
                start: start.addingTimeInterval(10),
                duration: 20,
                value: 8,
                unit: "m/s"
            ),
            sample(
                metric: .cyclingCadence,
                start: start,
                value: 82,
                unit: "rpm"
            ),
            sample(
                metric: .runningPower,
                start: start,
                value: 220,
                unit: "W"
            ),
            sample(
                metric: .oxygenSaturation,
                start: start,
                value: 98,
                unit: "%"
            ),
            sample(
                metric: .respiratoryRate,
                start: start,
                value: 18,
                unit: "breaths/min"
            ),
            sample(
                metric: .vo2Max,
                start: start,
                value: 48,
                unit: "mL/kg/min"
            )
        ]

        let summary =
            WorkoutHealthSummaryBuilder
                .makeSummary(
                    from: samples
                )

        #expect(summary.averageHeartRate == 120)
        #expect(summary.minimumHeartRate == 100)
        #expect(summary.maximumHeartRate == 140)
        #expect(summary.averageHeartRateVariability == 42)
        #expect(summary.heartRateRecoveryOneMinute == 28)
        #expect(summary.activeCalories == 200)
        #expect(summary.stepCount == 1000)
        #expect(summary.distanceMeters == 7400)
        #expect(summary.averageCadence == 82)
        #expect(summary.averagePowerWatts == 220)
        #expect(summary.averageOxygenSaturation == 98)
        #expect(summary.averageRespiratoryRate == 18)
        #expect(summary.vo2Max == 48)

        let expectedWeightedSpeed =
            ((5 * 10) + (8 * 20)) / 30.0

        #expect(
            summary.averageSpeedMetersPerSecond
                == expectedWeightedSpeed
        )
        #expect(
            summary.maximumSpeedMetersPerSecond
                == 8
        )
    }

    @Test("산소포화도 HealthKit fraction은 사용자 친화적 percent 값으로 변환된다")
    func oxygenSaturationIsNormalizedToPercent() throws {
        let descriptor = try #require(
            HealthMetricDescriptor.all.first {
                $0.metric == .oxygenSaturation
            }
        )

        let type = try #require(
            descriptor.quantityType
        )

        let date = Date(
            timeIntervalSince1970: 1_800_000_000
        )

        let healthKitSample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(
                unit: .percent(),
                doubleValue: 0.975
            ),
            start: date,
            end: date
        )

        #expect(
            descriptor.value(
                from: healthKitSample
            ) == 97.5
        )
    }

    @Test("HealthKit에 없는 runningCadence는 직접 조회하지 않는다")
    func runningCadenceIsNotQueriedAsHealthKitType() {
        #expect(
            !HealthMetricDescriptor.all.contains {
                $0.metric == .runningCadence
            }
        )

        #expect(
            HealthMetricDescriptor.all.contains {
                $0.metric == .cyclingCadence
            }
        )
    }

    @Test("1분 심박수 회복은 운동 종료 직후 구간까지 조회한다")
    func recoveryQueryRangeExtendsPastWorkoutEnd() throws {
        let descriptor = try #require(
            HealthMetricDescriptor.all.first {
                $0.metric
                    == .heartRateRecoveryOneMinute
            }
        )

        let start = Date(
            timeIntervalSince1970: 1_800_000_000
        )
        let end = start.addingTimeInterval(3600)

        let range = descriptor.queryRange(
            workoutStartDate: start,
            workoutEndDate: end
        )

        #expect(
            range.lowerBound
                == end.addingTimeInterval(-30)
        )
        #expect(
            range.upperBound
                == end.addingTimeInterval(120)
        )
    }

    @Test("샘플이 없으면 요약 값은 0이 아니라 nil이다")
    func emptySamplesProduceUnknownSummaryValues() {
        let summary =
            WorkoutHealthSummaryBuilder
                .makeSummary(
                    from: []
                )

        #expect(summary.averageHeartRate == nil)
        #expect(summary.activeCalories == nil)
        #expect(summary.distanceMeters == nil)
        #expect(summary.averagePowerWatts == nil)
    }
}

private extension WakTrainerServiceHealthKitTests {

    func sample(
        metric: WorkoutHealthMetric,
        start: Date,
        duration: TimeInterval = 0,
        value: Double,
        unit: String
    ) -> WorkoutHealthMetricSample {
        WorkoutHealthMetricSample(
            metric: metric,
            startDate: start,
            endDate:
                start.addingTimeInterval(
                    duration
                ),
            value: value,
            unit: unit
        )
    }
}
