import Foundation
import WakTrainerCoreModels

public enum HealthDataServiceError: Error, Equatable, LocalizedError, Sendable {
    case healthDataUnavailable
    case invalidDateRange
    case authorizationFailed(reason: String)
    case queryFailed(metric: WorkoutHealthMetric, reason: String)

    public var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is unavailable on this device."
        case .invalidDateRange:
            return "The workout end date must be later than the start date."
        case let .authorizationFailed(reason):
            return "Health data authorization failed: \(reason)"
        case let .queryFailed(metric, reason):
            return "Failed to read \(metric.rawValue): \(reason)"
        }
    }
}
