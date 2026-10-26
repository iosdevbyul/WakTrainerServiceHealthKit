import Foundation
import HealthKit

/// Opt-in iPhone workout collection for an external heart-rate sensor such as AirPods Pro 3.
/// This service does not alter the existing read-only HealthKitManager observation pipeline.
/// A caller must not start another HKWorkoutSession for the same workout.
@available(iOS 26.0, *)
public final class ExternalHeartRateWorkoutSession: NSObject, @unchecked Sendable {
    public enum SessionError: Error {
        case unavailable
        case alreadyRunning
        case authorizationDenied
        case collectionFailed
    }

    private let store: HKHealthStore
    private let lock = NSLock()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var continuation: AsyncStream<Double>.Continuation?
    private var starting = false

    public override convenience init() {
        self.init(store: HKHealthStore())
    }

    init(store: HKHealthStore) {
        self.store = store
        super.init()
    }

    /// Start the HealthKit workout that enables compatible external sensors on iPhone.
    /// Heart-rate values are in BPM; an empty stream is normal until the sensor reports data.
    /// The caller is responsible for invoking stop() even when the UI disappears.
    public func start(
        activityType: HKWorkoutActivityType = .other,
        locationType: HKWorkoutSessionLocationType = .unknown
    ) async throws -> AsyncStream<Double> {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SessionError.unavailable
        }

        let canStart = lock.withLock { () -> Bool in
            guard session == nil, !starting else { return false }
            starting = true
            return true
        }
        guard canStart else { throw SessionError.alreadyRunning }

        defer {
            lock.withLock { starting = false }
        }

        let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let workout = HKObjectType.workoutType()

        try await store.requestAuthorization(
            toShare: [workout],
            read: [heartRate, workout]
        )

        // HealthKit can return normally when the user declines read access.
        // In that case the stream simply receives no measurements.
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = locationType

        let newSession = try HKWorkoutSession(
            healthStore: store,
            configuration: configuration
        )
        let newBuilder = newSession.associatedWorkoutBuilder()
        newBuilder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store,
            workoutConfiguration: configuration
        )
        newSession.delegate = self
        newBuilder.delegate = self

        let stream = AsyncStream<Double> { streamContinuation in
            lock.withLock {
                session = newSession
                builder = newBuilder
                continuation = streamContinuation
            }
        }

        let startDate = Date()
        newSession.startActivity(with: startDate)
        do {
            let started = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Bool, Error>) in
                newBuilder.beginCollection(withStart: startDate) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                }
            }
            guard started else { throw SessionError.collectionFailed }
            return stream
        } catch {
            newSession.end()
            newBuilder.discardWorkout()
            lock.withLock {
                session = nil
                builder = nil
                continuation?.finish()
                continuation = nil
            }
            throw error
        }
    }

    /// Ends collection and saves the completed workout in HealthKit.
    /// Existing WakTrainer workout persistence remains the responsibility of its caller.
    public func stop() async throws {
        let current = lock.withLock { () -> (HKWorkoutSession, HKLiveWorkoutBuilder)? in
            guard let session, let builder else { return nil }
            self.session = nil
            self.builder = nil
            continuation?.finish()
            continuation = nil
            return (session, builder)
        }
        guard let (session, builder) = current else { return }
        session.end()

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: Date()) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        _ = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<HKWorkout?, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workout)
                }
            }
        }
    }

    private func publishHeartRate(from workoutBuilder: HKLiveWorkoutBuilder) {
        guard let stats = workoutBuilder.statistics(
            for: HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ), let quantity = stats.mostRecentQuantity() else { return }

        let bpm = quantity.doubleValue(
            for: HKUnit.count().unitDivided(by: .minute())
        )
        guard bpm.isFinite, bpm > 0 else { return }
        lock.withLock {
            guard builder === workoutBuilder else { return }
            continuation?.yield(bpm)
        }
    }
}

@available(iOS 26.0, *)
extension ExternalHeartRateWorkoutSession: HKWorkoutSessionDelegate {
    public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        lock.withLock {
            guard session === workoutSession else { return }
            continuation?.finish()
            continuation = nil
            session = nil
            builder = nil
        }
    }
}

@available(iOS 26.0, *)
extension ExternalHeartRateWorkoutSession: HKLiveWorkoutBuilderDelegate {
    public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        guard collectedTypes.contains(heartRate) else { return }
        publishHeartRate(from: workoutBuilder)
    }

    public func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {}
}
