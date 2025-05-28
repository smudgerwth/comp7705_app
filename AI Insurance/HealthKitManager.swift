//
//  HealthKitManager.swift
//  AI Insurance
//
//  Created by Aidan Wong on 28/5/2025.
//

import HealthKit
import SwiftUI

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var stepCount: Double? // Steps
    @Published var heartRate: Double? // Beats per minute
    @Published var restingHeartRate: Double? // Beats per minute
    @Published var activeEnergy: Double? // Calories
    @Published var bodyWeight: Double? // Kilograms
    @Published var bmi: Double? // BMI
    @Published var sleepHours: Double? // Hours
    @Published var biologicalSex: String? // Biological sex
    @Published var age: Int? // Age in years
    @Published var errorMessage: String?
    
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            print(errorMessage!)
            return
        }
        
        guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
              let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let bodyWeight = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bmi = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
              let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
              let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) else {
            errorMessage = "One or more HealthKit types are unavailable."
            print(errorMessage!)
            return
        }
        
        let typesToRead: Set = [stepCount, heartRate, restingHeartRate, activeEnergy, bodyWeight, bmi, sleepAnalysis, biologicalSex, dateOfBirth]
        
        // Check authorization status
        let status = healthStore.authorizationStatus(for: stepCount)
        DispatchQueue.main.async {
            if status == .sharingAuthorized {
                self.isAuthorized = true
                print("HealthKit permission already granted.")
                self.fetchAllData()
            } else {
                self.isAuthorized = false
                print("HealthKit permission not granted. Awaiting user action.")
            }
        }
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            print(errorMessage!)
            return
        }
        
        guard let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
              let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let bodyWeight = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bmi = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
              let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
              let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) else {
            errorMessage = "One or more HealthKit types are unavailable."
            print(errorMessage!)
            return
        }
        
        let typesToRead: Set = [stepCount, heartRate, restingHeartRate, activeEnergy, bodyWeight, bmi, sleepAnalysis, biologicalSex, dateOfBirth]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    print("HealthKit authorization granted.")
                    self.fetchAllData()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Authorization failed."
                    print("HealthKit authorization failed: \(self.errorMessage!)")
                }
            }
        }
    }
    
    func fetchAllData() {
        fetchStepCount()
        fetchHeartRate()
        fetchRestingHeartRate()
        fetchActiveEnergy()
        fetchBodyWeight()
        fetchBMI()
        fetchSleepAnalysis()
        fetchBiologicalSex()
        fetchAge()
    }
    
    private func fetchStepCount() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Step count query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.stepCount = nil
                    return
                }
                if let sum = result?.sumQuantity() {
                    self.stepCount = sum.doubleValue(for: HKUnit.count())
                } else {
                    self.stepCount = nil
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Heart rate query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.heartRate = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } else {
                    self.heartRate = nil
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchRestingHeartRate() {
        guard let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let query = HKSampleQuery(sampleType: restingHeartRateType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Resting heart rate query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.restingHeartRate = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.restingHeartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } else {
                    self.restingHeartRate = nil
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy() {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Active energy query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.activeEnergy = nil
                    return
                }
                if let sum = result?.sumQuantity() {
                    self.activeEnergy = sum.doubleValue(for: HKUnit.kilocalorie())
                } else {
                    self.activeEnergy = nil
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchBodyWeight() {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Body weight query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.bodyWeight = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.bodyWeight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                } else {
                    self.bodyWeight = nil
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchBMI() {
        guard let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) else { return }
        
        let query = HKSampleQuery(sampleType: bmiType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "BMI query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.bmi = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.bmi = sample.quantity.doubleValue(for: HKUnit.count())
                } else {
                    self.bmi = nil
                }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchSleepAnalysis() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Sleep analysis query failed: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    self.sleepHours = nil
                    return
                }
                let totalSleepSeconds = samples?.compactMap { sample -> Double? in
                    guard let sample = sample as? HKCategorySample, sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue else { return nil }
                    return sample.endDate.timeIntervalSince(sample.startDate)
                }.reduce(0, +) ?? 0
                self.sleepHours = totalSleepSeconds / 3600 // Convert to hours
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchBiologicalSex() {
        do {
            let biologicalSex = try healthStore.biologicalSex()
            DispatchQueue.main.async {
                switch biologicalSex.biologicalSex {
                case .notSet: self.biologicalSex = "Not Set"
                case .female: self.biologicalSex = "Female"
                case .male: self.biologicalSex = "Male"
                case .other: self.biologicalSex = "Other"
                @unknown default: self.biologicalSex = "Unknown"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Biological sex query failed: \(error.localizedDescription)"
                print(self.errorMessage!)
                self.biologicalSex = nil
            }
        }
    }
    
    private func fetchAge() {
        do {
            let dateOfBirth = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current
            let now = Date()
            if let birthDate = calendar.date(from: dateOfBirth) {
                let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
                DispatchQueue.main.async {
                    self.age = ageComponents.year
                }
            } else {
                DispatchQueue.main.async {
                    self.age = nil
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Date of birth query failed: \(error.localizedDescription)"
                print(self.errorMessage!)
                self.age = nil
            }
        }
    }
}
