//
//  HealthKitManager.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//
import HealthKit
import SwiftUI
import os.log

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var stepCount: Double?           // Monthly average daily steps
    @Published var heartRate: Double?           // Monthly average heart rate
    @Published var activeEnergy: Double?        // Monthly average daily active energy
    @Published var bodyWeight: Double?          // Will now store monthly average body weight
    @Published var bmi: Double?                 // Will now store monthly average BMI
    @Published var sleepHours: Double?          // Monthly average daily sleep
    @Published var biologicalSex: String?
    @Published var age: Int?
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.AIInsurance", category: "HealthKitManager")

    // --- checkAuthorizationStatus() and requestAuthorization() remain the same ---
    // (Your existing authorization logic from the file you provided)
    func checkAuthorizationStatus() {
        logger.info("Checking HealthKit authorization status")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            logger.error("\(self.errorMessage!)")
            return
        }
        
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let bodyWeightType = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
              let sleepAnalysisType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
              let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) else {
            errorMessage = "One or more HealthKit types are unavailable."
            logger.error("\(self.errorMessage!)")
            return
        }
        
        let typesToRead: Set = [stepCountType, heartRateType, activeEnergyType, bodyWeightType, bmiType, sleepAnalysisType, biologicalSexType, dateOfBirthType]
        
        var hasAccess = false
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            logger.debug("Authorization status for \(type.identifier): \(status.rawValue) (\(status.description))")
            if status == .sharingAuthorized {
                hasAccess = true
            }
        }
        
        var fetchedCriticalData = false
        
        do {
            _ = try healthStore.biologicalSex()
            fetchedCriticalData = true
            logger.debug("Biological sex accessible")
        } catch {
            logger.debug("Biological sex not accessible: \(error.localizedDescription)")
        }
        
        do {
            _ = try healthStore.dateOfBirthComponents()
            fetchedCriticalData = true
            logger.debug("Date of birth accessible")
        } catch {
            logger.debug("Date of birth not accessible: \(error.localizedDescription)")
        }
        
        if let bmiSampleType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            let query = HKSampleQuery(sampleType: bmiSampleType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let _ = samples?.first as? HKQuantitySample {
                    DispatchQueue.main.async {
                        self.logger.debug("BMI accessible")
                        // self.isAuthorized = true // Direct assignment here might be redundant
                    }
                }
            }
            healthStore.execute(query)
        }
        
        DispatchQueue.main.async {
            self.isAuthorized = hasAccess || fetchedCriticalData
            self.logger.info("HealthKit authorization state: isAuthorized=\(self.isAuthorized)")
            if self.isAuthorized {
                self.fetchAllData()
            }
        }
    }
    
    func requestAuthorization() {
        logger.info("Requesting HealthKit authorization")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            logger.error("\(self.errorMessage!)")
            return
        }
        
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let bodyWeightType = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
              let sleepAnalysisType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
              let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) else {
            errorMessage = "One or more HealthKit types are unavailable."
            logger.error("\(self.errorMessage!)")
            return
        }
        
        let typesToRead: Set = [stepCountType, heartRateType, activeEnergyType, bodyWeightType, bmiType, sleepAnalysisType, biologicalSexType, dateOfBirthType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    self.logger.info("HealthKit authorization granted")
                    self.fetchAllData()
                } else {
                    self.isAuthorized = false
                    self.errorMessage = error?.localizedDescription ?? "Authorization failed."
                    self.logger.error("HealthKit authorization failed: \(self.errorMessage!)")
                }
            }
        }
    }

    func fetchAllData() {
        logger.info("Fetching all HealthKit data (monthly averages where applicable)")
        fetchMonthlyAverageStepCount()
        fetchMonthlyAverageHeartRate()
        fetchMonthlyAverageActiveEnergy()
        fetchMonthlyAverageBodyWeight()         // Updated call
        fetchMonthlyAverageBMI()                // Updated call
        fetchMonthlyAverageSleepAnalysis()
        fetchBiologicalSex()                    // Characteristic
        fetchAge()                              // Characteristic
    }

    // MARK: - Modified Fetch Methods for Monthly Averages

    private func fetchMonthlyAverageStepCount() {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            logger.error("Step count type unavailable.")
            DispatchQueue.main.async { self.stepCount = nil }
            return
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else {
            logger.error("Failed to calculate start date for monthly steps.")
            DispatchQueue.main.async { self.stepCount = nil }
            return
        }
        let anchorDate = calendar.startOfDay(for: startDate)
        var interval = DateComponents()
        interval.day = 1

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: anchorDate, intervalComponents: interval)

        query.initialResultsHandler = { _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("Monthly step count collection query failed: \(error.localizedDescription)")
                    self.stepCount = nil; return
                }
                guard let result = result else {
                    self.logger.error("No result for monthly step count collection query.")
                    self.stepCount = nil; return
                }
                var totalStepsOverPeriod = 0.0; var daysWithData = 0
                result.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    if let sum = statistics.sumQuantity() { totalStepsOverPeriod += sum.doubleValue(for: HKUnit.count()); daysWithData += 1 }
                }
                if daysWithData > 0 { self.stepCount = totalStepsOverPeriod / Double(daysWithData); self.logger.debug("Monthly average daily step count fetched: \(self.stepCount ?? 0)")
                } else { self.stepCount = 0; self.logger.debug("No step data found for the last 30 days.") }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchMonthlyAverageHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            logger.error("Heart rate type unavailable."); DispatchQueue.main.async { self.heartRate = nil }; return }
        let calendar = Calendar.current; let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else {
            logger.error("Failed to calculate start date for monthly heart rate."); DispatchQueue.main.async { self.heartRate = nil }; return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            DispatchQueue.main.async {
                if let error = error { self.logger.error("Monthly average heart rate query failed: \(error.localizedDescription)"); self.heartRate = nil; return }
                if let averageQuantity = result?.averageQuantity() {
                    self.heartRate = averageQuantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.logger.debug("Monthly average heart rate fetched: \(self.heartRate ?? 0)")
                } else { self.heartRate = nil; self.logger.debug("No heart rate data available to average for the last 30 days.") }
            }
        }
        healthStore.execute(query)
    }

    private func fetchMonthlyAverageActiveEnergy() {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            logger.error("Active energy type unavailable."); DispatchQueue.main.async { self.activeEnergy = nil }; return }
        let calendar = Calendar.current; let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else {
            logger.error("Failed to calculate start date for monthly active energy."); DispatchQueue.main.async { self.activeEnergy = nil }; return }
        let anchorDate = calendar.startOfDay(for: startDate); var interval = DateComponents(); interval.day = 1
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: anchorDate, intervalComponents: interval)
        query.initialResultsHandler = { _, result, error in
            DispatchQueue.main.async {
                if let error = error { self.logger.error("Monthly active energy collection query failed: \(error.localizedDescription)"); self.activeEnergy = nil; return }
                guard let result = result else { self.logger.error("No result for monthly active energy collection query."); self.activeEnergy = nil; return }
                var totalEnergyOverPeriod = 0.0; var daysWithData = 0
                result.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    if let sum = statistics.sumQuantity() { totalEnergyOverPeriod += sum.doubleValue(for: HKUnit.kilocalorie()); daysWithData += 1 }
                }
                if daysWithData > 0 { self.activeEnergy = totalEnergyOverPeriod / Double(daysWithData); self.logger.debug("Monthly average daily active energy fetched: \(self.activeEnergy ?? 0)")
                } else { self.activeEnergy = 0; self.logger.debug("No active energy data found for the last 30 days.") }
            }
        }
        healthStore.execute(query)
    }

    // NEW: Method to fetch monthly average Body Weight
    private func fetchMonthlyAverageBodyWeight() {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            logger.error("Body Mass (Weight) type unavailable."); DispatchQueue.main.async { self.bodyWeight = nil }; return }
        let calendar = Calendar.current; let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else {
            logger.error("Failed to calculate start date for monthly body weight."); DispatchQueue.main.async { self.bodyWeight = nil }; return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: weightType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            DispatchQueue.main.async {
                if let error = error { self.logger.error("Monthly average body weight query failed: \(error.localizedDescription)"); self.bodyWeight = nil; return }
                if let averageQuantity = result?.averageQuantity() {
                    self.bodyWeight = averageQuantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)) // Kilograms
                    self.logger.debug("Monthly average body weight fetched: \(self.bodyWeight ?? 0)")
                } else { self.bodyWeight = nil; self.logger.debug("No body weight data available to average for the last 30 days.") }
            }
        }
        healthStore.execute(query)
    }
    
    // NEW: Method to fetch monthly average BMI
    private func fetchMonthlyAverageBMI() {
        guard let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) else {
            logger.error("BMI type unavailable."); DispatchQueue.main.async { self.bmi = nil }; return }
        let calendar = Calendar.current; let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else {
            logger.error("Failed to calculate start date for monthly BMI."); DispatchQueue.main.async { self.bmi = nil }; return }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: bmiType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            DispatchQueue.main.async {
                if let error = error { self.logger.error("Monthly average BMI query failed: \(error.localizedDescription)"); self.bmi = nil; return }
                if let averageQuantity = result?.averageQuantity() {
                    self.bmi = averageQuantity.doubleValue(for: HKUnit.count()) // BMI is a count
                    self.logger.debug("Monthly average BMI fetched: \(self.bmi ?? 0)")
                } else { self.bmi = nil; self.logger.debug("No BMI data available to average for the last 30 days.") }
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchMonthlyAverageSleepAnalysis() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            logger.error("Sleep analysis type unavailable."); DispatchQueue.main.async { self.sleepHours = nil }; return
        }
        let calendar = Calendar.current; let now = Date()
        let endDate = calendar.startOfDay(for: now)
        
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else { // Start 30 days before end of yesterday
            logger.error("Failed to calculate start date for monthly sleep."); DispatchQueue.main.async { self.sleepHours = nil }; return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(keyPath: \HKSample.startDate, ascending: true)]) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.logger.error("Monthly sleep analysis query failed: \(error.localizedDescription)")
                    self.sleepHours = nil
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    self.sleepHours = 0 // Or nil, if no samples at all
                    self.logger.debug("No sleep category samples found for the last 30 days.")
                    return
                }

                if sleepSamples.isEmpty {
                    self.sleepHours = 0 // No actual "asleep" data found after filtering
                    self.logger.debug("No 'asleep' (Unspecified, Core, Deep, REM) sleep samples found after filtering for the last 30 days.")
                    return
                }

                // --- New logic to group by day and calculate daily totals ---
                var dailySleepTotals: [Date: TimeInterval] = [:] // Key: Start of day, Value: Total sleep in seconds for that day

                for sample in sleepSamples {
                    let dayOfSampleStart = calendar.startOfDay(for: sample.startDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    dailySleepTotals[dayOfSampleStart, default: 0] += duration
                }

                if dailySleepTotals.isEmpty {
                    self.sleepHours = 0
                    self.logger.debug("No days with sleep data found after processing samples.")
                    return
                }

                let totalSleepDurationAcrossDaysWithData = dailySleepTotals.values.reduce(0, +)
                let numberOfDaysWithSleepData = dailySleepTotals.count
                
                // Calculate average daily sleep only for days that had sleep data
                let averageDailySleepHours = (totalSleepDurationAcrossDaysWithData / 3600.0) / Double(numberOfDaysWithSleepData)
                
                self.sleepHours = averageDailySleepHours
                self.logger.debug("Monthly average daily sleep hours (for days with data) fetched: \(self.sleepHours ?? 0), based on \(numberOfDaysWithSleepData) days of data.")
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchBiologicalSex() {
        do {
            let biologicalSexObject = try healthStore.biologicalSex()
            DispatchQueue.main.async {
                switch biologicalSexObject.biologicalSex {
                case .notSet: self.biologicalSex = "Not Set"; case .female: self.biologicalSex = "Female"; case .male: self.biologicalSex = "Male"; case .other: self.biologicalSex = "Other"; @unknown default: self.biologicalSex = "Unknown"
                }
                self.logger.debug("Biological sex fetched: \(self.biologicalSex ?? "nil")")
            }
        } catch { DispatchQueue.main.async { self.logger.error("Biological sex query failed: \(error.localizedDescription)"); self.biologicalSex = nil } }
    }
    
    private func fetchAge() {
        do {
            let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
            let calendar = Calendar.current; let now = Date()
            if let birthDate = calendar.date(from: dateOfBirthComponents) {
                let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
                DispatchQueue.main.async { self.age = ageComponents.year; if let age = self.age { self.logger.debug("Age fetched: \(age)") } }
            } else { DispatchQueue.main.async { self.age = nil; self.logger.debug("Could not calculate birth date from components for age.") } }
        } catch { DispatchQueue.main.async { self.logger.error("Date of birth query failed for age: \(error.localizedDescription)"); self.age = nil } }
    }
}

extension HKAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"; case .sharingDenied: return "Sharing Denied"; case .sharingAuthorized: return "Sharing Authorized"; @unknown default: return "Unknown"
        }
    }
}
