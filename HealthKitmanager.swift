//
//  HealthKitmanager.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//


import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        healthStore.requestAuthorization(toShare: [], read: [stepType]) { success, error in
            completion(success)
        }
    }

    func fetchTodayStepCount(completion: @escaping (Int) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(0)
            return
        }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            var steps = 0
            if let quantity = result?.sumQuantity() {
                steps = Int(quantity.doubleValue(for: HKUnit.count()))
            }
            DispatchQueue.main.async {
                completion(steps)
            }
        }

        healthStore.execute(query)
    }
}
