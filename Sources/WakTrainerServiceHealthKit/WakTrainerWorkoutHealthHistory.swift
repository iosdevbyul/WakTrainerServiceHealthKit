import Foundation
import HealthKit

/// Operations on workouts written by WakTrainer, never other apps' workout data.
/// Does not delete local WakTrainer history or measurements owned by other sources.
public struct WakTrainerWorkoutHealthHistory {
    private let store: HKHealthStore

    public init() {
        self.store = HKHealthStore()
    }

    /// Returns the count of workouts created by a WakTrainer app target.
    public func savedWorkoutCount() async throws -> Int {
        try await authorizedWorkouts().count
    }

    /// Deletes only HKWorkout objects from the recognized WakTrainer bundle IDs.
    /// Call only after the person explicitly confirms this destructive action.
    @discardableResult
    public func deleteSavedWorkouts() async throws -> Int {
        let workouts = try await authorizedWorkouts()
        guard !workouts.isEmpty else { return 0 }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.delete(workouts) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HistoryError.deletionFailed)
                }
            }
        }
        return workouts.count
    }

    public enum HistoryError: Error {
        case healthDataUnavailable
        case deletionFailed
    }

    private func authorizedWorkouts() async throws -> [HKWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HistoryError.healthDataUnavailable
        }
        let workoutType = HKObjectType.workoutType()
        try await store.requestAuthorization(toShare: [workoutType], read: [workoutType])
        let all = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKWorkout })
                }
            }
            store.execute(query)
        }
        let appBundleIDs: Set<String> = [
            "com.tris.WakTrainer",
            "com.tris.WakTrainerDemo",
            "com.tris.WakTrainerDeviceTest"
        ]
        return all.filter { workout in
            appBundleIDs.contains(workout.sourceRevision.source.bundleIdentifier)
        }
    }
}
