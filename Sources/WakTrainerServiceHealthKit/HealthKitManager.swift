import Foundation
import HealthKit
import WakTrainerCoreModels

public final class HealthKitManager: HealthKitManagerProtocol, @unchecked Sendable {
    private let healthStore = HKHealthStore()
    private let lock = NSLock()
    
    private var _isAuthorized = false
    private var activeQuery: HKObserverQuery?
    private var streamContinuation: AsyncStream<HealthSnapshot>.Continuation?
    
    public init() {}
    
    public var isAuthorized: Bool {
        get async {
            lock.withLock { _isAuthorized }
        }
    }
    
    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                self?.lock.withLock {
                    self?._isAuthorized = success
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    public func startObservingData() -> AsyncStream<HealthSnapshot> {
        AsyncStream { continuation in
            self.lock.withLock {
                self.streamContinuation = continuation
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.stopQueryInternal()
            }
            
            self.startHeartRateQuery()
        }
    }
    
    public func stopObservingData() async {
        stopQueryInternal()
        lock.withLock {
            streamContinuation?.finish()
            streamContinuation = nil
        }
    }
    
    private func stopQueryInternal() {
        lock.withLock {
            if let query = activeQuery {
                healthStore.stop(query)
                activeQuery = nil
            }
        }
    }
    
    private func startHeartRateQuery() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            self?.fetchLatestHeartRate()
        }
        
        lock.withLock {
            self.activeQuery = query
        }
        healthStore.execute(query)
    }
    
    private func fetchLatestHeartRate() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            
            self?.lock.withLock {
                let snapshot = HealthSnapshot(heartRate: hr)
                self?.streamContinuation?.yield(snapshot)
            }
        }
        
        healthStore.execute(query)
    }
}
