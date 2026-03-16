import HealthKit
import Foundation

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    let store = HKHealthStore()

    private init() {}

    var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let ids: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime, .heartRateVariabilitySDNN, .bodyMass
        ]
        for id in ids {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let stand = HKObjectType.categoryType(forIdentifier: .appleStandHour) { types.insert(stand) }
        if let mind = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(mind) }
        return types
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(false); return }
        store.requestAuthorization(toShare: nil, read: readTypes) { ok, _ in completion(ok) }
    }

    // Steps today
    func fetchTodayStepCount(completion: @escaping (Int) -> Void) {
        fetchTodayQuantity(.stepCount, unit: .count()) { v in completion(Int(v)) }
    }

    // Active energy (kcal) today
    func fetchTodayActiveCalories(completion: @escaping (Double) -> Void) {
        fetchTodayQuantity(.activeEnergyBurned, unit: .kilocalorie(), completion: completion)
    }

    // Exercise minutes today
    func fetchTodayExerciseMinutes(completion: @escaping (Double) -> Void) {
        fetchTodayQuantity(.appleExerciseTime, unit: .minute(), completion: completion)
    }

    // HRV (ms) — latest sample
    func fetchLatestHRV(completion: @escaping (Double?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { completion(nil); return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let v = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            completion(v)
        }
        store.execute(q)
    }

    // Sleep analysis last night
    func fetchLastNightSleepHours(completion: @escaping (Double) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { completion(0); return }
        let cal = Calendar.current
        let now = Date()
        let yesterday = cal.date(byAdding: .hour, value: -24, to: now) ?? now.addingTimeInterval(-86400)
        let pred = HKQuery.predicateForSamples(withStart: yesterday, end: now)
        let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let total = (samples as? [HKCategorySample])?.filter {
                $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 } ?? 0
            completion(total)
        }
        store.execute(q)
    }

    // Stand hours today
    func fetchTodayStandHours(completion: @escaping (Int) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { completion(0); return }
        let pred = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
        let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let stood = (samples as? [HKCategorySample])?.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count ?? 0
            completion(stood)
        }
        store.execute(q)
    }

    // Mindful minutes today
    func fetchTodayMindfulMinutes(completion: @escaping (Double) -> Void) {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { completion(0); return }
        let pred = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
        let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let mins = (samples as? [HKCategorySample])?.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 } ?? 0
            completion(mins)
        }
        store.execute(q)
    }

    private func fetchTodayQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { completion(0); return }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
            completion(stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
        }
        store.execute(q)
    }
}
