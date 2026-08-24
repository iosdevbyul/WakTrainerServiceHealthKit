import Foundation
import HealthKit
import WakTrainerCoreModels

public final class HealthKitManager: NSObject, HealthKitManagerProtocol, @unchecked Sendable {
    private let healthStore = HKHealthStore()
    private let lock = NSLock()
    
    private var _isAuthorized = false
    private var streamContinuation: AsyncStream<HealthSnapshot>.Continuation?
    
    // iOS 실시간 쿼리 및 Anchor 저장
    private var activeQueries: [HKQuery] = []
    private var heartRateAnchor: HKQueryAnchor?
    private var energyAnchor: HKQueryAnchor?
    private var stepAnchor: HKQueryAnchor?
    
    // 실시간 수치 보관
    private var currentHeartRate: Double = 0
    private var currentEnergy: Double = 0
    private var currentSteps: Double = 0
    private var currentDistance: Double = 0

    public override init() {
        super.init()
    }
    
    public var isAuthorized: Bool {
        get async {
            lock.withLock { _isAuthorized }
        }
    }
    
    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
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
                self?.lock.withLock { self?._isAuthorized = success }
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - 실시간 수집 시작
    public func startObservingData() -> AsyncStream<HealthSnapshot> {
        AsyncStream { continuation in
            self.lock.withLock {
                self.streamContinuation = continuation
            }
            
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.stopObservingData()
                }
            }
            
            self.startRealtimeQueries()
        }
    }
    
    // MARK: - 실시간 수집 종료
    public func stopObservingData() async {
        lock.withLock {
            for query in activeQueries {
                healthStore.stop(query)
            }
            activeQueries.removeAll()
            
            streamContinuation?.finish()
            streamContinuation = nil
        }
    }
    
    // MARK: - iOS 순수 Anchored Query 실행
    private func startRealtimeQueries() {
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: now, end: nil, options: .strictStartDate)
        
        // 1. 심박수
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let hrQuery = HKAnchoredObjectQuery(
                type: hrType,
                predicate: predicate,
                anchor: heartRateAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, newAnchor, _ in
                self?.heartRateAnchor = newAnchor
                self?.processHeartRateSamples(samples)
            }
            
            hrQuery.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
                self?.heartRateAnchor = newAnchor
                self?.processHeartRateSamples(samples)
            }
            
            lock.withLock { activeQueries.append(hrQuery) }
            healthStore.execute(hrQuery)
        }
        
        // 2. 소모 칼로리
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyQuery = HKAnchoredObjectQuery(
                type: energyType,
                predicate: predicate,
                anchor: energyAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, newAnchor, _ in
                self?.energyAnchor = newAnchor
                self?.processEnergySamples(samples)
            }
            
            energyQuery.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
                self?.energyAnchor = newAnchor
                self?.processEnergySamples(samples)
            }
            
            lock.withLock { activeQueries.append(energyQuery) }
            healthStore.execute(energyQuery)
        }
        
        // 3. 걸음 수
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let stepQuery = HKAnchoredObjectQuery(
                type: stepType,
                predicate: predicate,
                anchor: stepAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, newAnchor, _ in
                self?.stepAnchor = newAnchor
                self?.processStepSamples(samples)
            }
            
            stepQuery.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
                self?.stepAnchor = newAnchor
                self?.processStepSamples(samples)
            }
            
            lock.withLock { activeQueries.append(stepQuery) }
            healthStore.execute(stepQuery)
        }
    }
    
    // MARK: - Sample Processing
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        let val = lastSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        
        lock.withLock {
            self.currentHeartRate = val
            self.yieldSnapshot()
        }
    }
    
    private func processEnergySamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        let addedKcal = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
        
        lock.withLock {
            self.currentEnergy += addedKcal
            self.yieldSnapshot()
        }
    }
    
    private func processStepSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        let addedSteps = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) }
        
        lock.withLock {
            self.currentSteps += addedSteps
            self.yieldSnapshot()
        }
    }
    
    private func yieldSnapshot() {
        let snapshot = HealthSnapshot(
            heartRate: currentHeartRate,
            stepCount: currentSteps,
            activeCalories: currentEnergy,
            distance: currentDistance
        )
        streamContinuation?.yield(snapshot)
    }
}
