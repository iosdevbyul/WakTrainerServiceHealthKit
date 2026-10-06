import Foundation
import HealthKit
import WakTrainerCoreModels

public final class HealthKitManager: NSObject,
                                     HealthKitManagerProtocol,
                                     @unchecked Sendable {

    private let healthStore: HKHealthStore
    private let lock = NSLock()

    private var authorizationRequestCompleted = false

    private var streamContinuation:
        AsyncStream<HealthSnapshot>.Continuation?

    private var activeQueries: [HKQuery] = []
    private var liveAnchors: [String: HKQueryAnchor] = [:]

    private var currentHeartRate: Double = 0
    private var currentEnergy: Double = 0
    private var currentSteps: Double = 0
    private var currentDistance: Double = 0

    public override convenience init() {
        self.init(healthStore: HKHealthStore())
    }

    init(
        healthStore: HKHealthStore
    ) {
        self.healthStore = healthStore
        super.init()
    }

    public var isAuthorized: Bool {
        get async {
            lock.withLock {
                authorizationRequestCompleted
            }
        }
    }

    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthDataServiceError.healthDataUnavailable
        }

        let readTypes = Set(
            HealthMetricDescriptor.all.compactMap(
                \.quantityType
            )
        )

        do {
            let success: Bool = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Bool, Error>) in

                healthStore.requestAuthorization(
                    toShare: [],
                    read: readTypes
                ) { success, error in
                    if let error {
                        continuation.resume(
                            throwing: error
                        )
                        return
                    }

                    continuation.resume(
                        returning: success
                    )
                }
            }

            lock.withLock {
                authorizationRequestCompleted = success
            }

            return success
        } catch {
            throw HealthDataServiceError
                .authorizationFailed(
                    reason: error.localizedDescription
                )
        }
    }

    public func startObservingData()
        -> AsyncStream<HealthSnapshot> {

        AsyncStream { continuation in
            let previousState = lock.withLock {
                let queries = activeQueries
                let previousContinuation =
                    streamContinuation

                activeQueries.removeAll()
                liveAnchors.removeAll()

                currentHeartRate = 0
                currentEnergy = 0
                currentSteps = 0
                currentDistance = 0

                streamContinuation = continuation

                return (
                    queries,
                    previousContinuation
                )
            }

            previousState.0.forEach {
                healthStore.stop($0)
            }

            previousState.1?.finish()

            continuation.onTermination = {
                [weak self] _ in

                Task {
                    await self?.stopObservingData()
                }
            }

            startRealtimeQueries(
                from: Date()
            )
        }
    }

    public func stopObservingData() async {
        let state = lock.withLock {
            let queries = activeQueries
            let continuation = streamContinuation

            activeQueries.removeAll()
            liveAnchors.removeAll()
            streamContinuation = nil

            return (
                queries,
                continuation
            )
        }

        state.0.forEach {
            healthStore.stop($0)
        }

        state.1?.finish()
    }

    public func fetchWorkoutHealthData(
        from startDate: Date,
        to endDate: Date
    ) async throws -> WorkoutHealthData {
        guard endDate > startDate else {
            throw HealthDataServiceError
                .invalidDateRange
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthDataServiceError
                .healthDataUnavailable
        }

        let descriptors =
            HealthMetricDescriptor.all.filter {
                $0.quantityType != nil
            }

        var collectedSamples:
            [WorkoutHealthMetricSample] = []

        var successfulQueryCount = 0
        var firstError: HealthDataServiceError?

        await withTaskGroup(
            of: MetricQueryResult.self
        ) { group in
            for descriptor in descriptors {
                group.addTask {
                    do {
                        let samples =
                            try await self.fetchSamples(
                                for: descriptor,
                                workoutStartDate: startDate,
                                workoutEndDate: endDate
                            )

                        return .success(
                            samples
                        )
                    } catch let error
                        as HealthDataServiceError {

                        return .failure(
                            error
                        )
                    } catch {
                        return .failure(
                            .queryFailed(
                                metric: descriptor.metric,
                                reason:
                                    error.localizedDescription
                            )
                        )
                    }
                }
            }

            for await result in group {
                switch result {
                case let .success(samples):
                    successfulQueryCount += 1
                    collectedSamples.append(
                        contentsOf: samples
                    )

                case let .failure(error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
        }

        if successfulQueryCount == 0,
           let firstError {
            throw firstError
        }

        collectedSamples.sort {
            if $0.startDate == $1.startDate {
                return $0.metric.rawValue
                    < $1.metric.rawValue
            }

            return $0.startDate < $1.startDate
        }

        return WorkoutHealthData(
            summary:
                WorkoutHealthSummaryBuilder
                    .makeSummary(
                        from: collectedSamples
                    ),
            samples: collectedSamples
        )
    }
}

// MARK: - Workout range queries

private extension HealthKitManager {

    enum MetricQueryResult:
        @unchecked Sendable {

        case success(
            [WorkoutHealthMetricSample]
        )

        case failure(
            HealthDataServiceError
        )
    }

    func fetchSamples(
        for descriptor: HealthMetricDescriptor,
        workoutStartDate: Date,
        workoutEndDate: Date
    ) async throws
        -> [WorkoutHealthMetricSample] {

        guard let quantityType =
                descriptor.quantityType else {
            return []
        }

        let range = descriptor.queryRange(
            workoutStartDate: workoutStartDate,
            workoutEndDate: workoutEndDate
        )

        let predicate =
            HKQuery.predicateForSamples(
                withStart: range.lowerBound,
                end: range.upperBound,
                options: [
                    .strictStartDate,
                    .strictEndDate
                ]
            )

        let sortDescriptors = [
            NSSortDescriptor(
                key:
                    HKSampleSortIdentifierStartDate,
                ascending: true
            )
        ]

        let quantitySamples:
            [HKQuantitySample]

        do {
            quantitySamples =
                try await withCheckedThrowingContinuation {
                    continuation in

                    let query = HKSampleQuery(
                        sampleType: quantityType,
                        predicate: predicate,
                        limit:
                            HKObjectQueryNoLimit,
                        sortDescriptors:
                            sortDescriptors
                    ) {
                        _, samples, error in

                        if let error {
                            continuation.resume(
                                throwing: error
                            )
                            return
                        }

                        continuation.resume(
                            returning:
                                samples
                                as? [
                                    HKQuantitySample
                                ] ?? []
                        )
                    }

                    healthStore.execute(
                        query
                    )
                }
        } catch {
            throw HealthDataServiceError
                .queryFailed(
                    metric: descriptor.metric,
                    reason:
                        error.localizedDescription
                )
        }

        return quantitySamples.map {
            sample in

            WorkoutHealthMetricSample(
                metric: descriptor.metric,
                startDate: sample.startDate,
                endDate: sample.endDate,
                value:
                    descriptor.value(
                        from: sample
                    ),
                unit:
                    descriptor.unitSymbol,
                sourceName:
                    sample.sourceRevision
                        .source.name,
                sourceBundleIdentifier:
                    sample.sourceRevision
                        .source
                        .bundleIdentifier
            )
        }
    }
}

// MARK: - Realtime observation

private extension HealthKitManager {

    func startRealtimeQueries(
        from startDate: Date
    ) {
        startRealtimeQuery(
            descriptor: .liveHeartRate,
            from: startDate
        )

        startRealtimeQuery(
            descriptor: .liveActiveEnergy,
            from: startDate
        )

        startRealtimeQuery(
            descriptor: .liveStepCount,
            from: startDate
        )

        startRealtimeQuery(
            descriptor: .liveDistance,
            from: startDate
        )
    }

    func startRealtimeQuery(
        descriptor: HealthMetricDescriptor,
        from startDate: Date
    ) {
        guard let quantityType =
                descriptor.quantityType else {
            return
        }

        let key = descriptor.metric.rawValue

        let predicate =
            HKQuery.predicateForSamples(
                withStart: startDate,
                end: nil,
                options: .strictStartDate
            )

        let anchor = lock.withLock {
            liveAnchors[key]
        }

        let query =
            HKAnchoredObjectQuery(
                type: quantityType,
                predicate: predicate,
                anchor: anchor,
                limit:
                    HKObjectQueryNoLimit
            ) {
                [weak self]
                _, samples, _, newAnchor, error in

                guard error == nil else {
                    return
                }

                self?.handleRealtimeSamples(
                    samples,
                    descriptor: descriptor,
                    anchor: newAnchor
                )
            }

        query.updateHandler = {
            [weak self]
            _, samples, _, newAnchor, error in

            guard error == nil else {
                return
            }

            self?.handleRealtimeSamples(
                samples,
                descriptor: descriptor,
                anchor: newAnchor
            )
        }

        lock.withLock {
            activeQueries.append(query)
        }

        healthStore.execute(query)
    }

    func handleRealtimeSamples(
        _ samples: [HKSample]?,
        descriptor: HealthMetricDescriptor,
        anchor: HKQueryAnchor?
    ) {
        let quantitySamples =
            samples as? [HKQuantitySample]
            ?? []

        let values = quantitySamples.map {
            descriptor.value(from: $0)
        }

        lock.withLock {
            if let anchor {
                liveAnchors[
                    descriptor.metric.rawValue
                ] = anchor
            }

            switch descriptor.metric {
            case .heartRate:
                if let latest =
                    values.last {
                    currentHeartRate =
                        latest
                }

            case .activeEnergyBurned:
                currentEnergy +=
                    values.reduce(0, +)

            case .stepCount:
                currentSteps +=
                    values.reduce(0, +)

            case .distanceWalkingRunning:
                currentDistance +=
                    values.reduce(0, +)

            default:
                break
            }

            yieldSnapshotLocked()
        }
    }

    func yieldSnapshotLocked() {
        streamContinuation?.yield(
            HealthSnapshot(
                heartRate:
                    currentHeartRate,
                stepCount:
                    currentSteps,
                activeCalories:
                    currentEnergy,
                distance:
                    currentDistance
            )
        )
    }
}
