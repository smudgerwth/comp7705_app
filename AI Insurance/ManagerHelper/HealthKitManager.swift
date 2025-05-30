import HealthKit
import SwiftUI
import os.log

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var stepCount: Double?
    @Published var heartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var activeEnergy: Double?
    @Published var bodyWeight: Double?
    @Published var bmi: Double?
    @Published var sleepHours: Double?
    @Published var biologicalSex: String?
    @Published var age: Int?
    @Published var errorMessage: String?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.AIInsurance", category: "HealthKitManager")
    
    func checkAuthorizationStatus() {
        logger.info("Checking HealthKit authorization status")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            logger.error("\(self.errorMessage!)")
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
            logger.error("\(self.errorMessage!)")
            return
        }
        
        let typesToRead: Set = [stepCount, heartRate, restingHeartRate, activeEnergy, bodyWeight, bmi, sleepAnalysis, biologicalSex, dateOfBirth]
        
        // Log authorization status for all types
        var hasAccess = false
        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            logger.debug("Authorization status for \(type.identifier): \(status.rawValue) (\(status.description))")
            if status == .sharingAuthorized {
                hasAccess = true
            }
        }
        
        // Fallback: Check if critical data can be fetched
        var fetchedCriticalData = false
        
        // Check biological sex access
        do {
            _ = try healthStore.biologicalSex()
            fetchedCriticalData = true
            logger.debug("Biological sex accessible")
        } catch {
            logger.debug("Biological sex not accessible: \(error.localizedDescription)")
        }
        
        // Check date of birth access
        do {
            _ = try healthStore.dateOfBirthComponents()
            fetchedCriticalData = true
            logger.debug("Date of birth accessible")
        } catch {
            logger.debug("Date of birth not accessible: \(error.localizedDescription)")
        }
        
        // Check BMI via sample query
        if let bmiType = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            let query = HKSampleQuery(sampleType: bmiType, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let _ = samples?.first as? HKQuantitySample {
                    DispatchQueue.main.async {
                        self.logger.debug("BMI accessible")
                        self.isAuthorized = true
                    }
                }
            }
            healthStore.execute(query)
        }
        
        DispatchQueue.main.async {
            // Set isAuthorized if any access is confirmed
            self.isAuthorized = hasAccess || fetchedCriticalData
            self.logger.info("HealthKit authorization state: isAuthorized=\(self.isAuthorized)")
            // Always fetch data to load what's available
            self.fetchAllData()
        }
    }
    
    func requestAuthorization() {
        logger.info("Requesting HealthKit authorization")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            logger.error("\(self.errorMessage!)")
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
            logger.error("\(self.errorMessage!)")
            return
        }
        
        let typesToRead: Set = [stepCount, heartRate, restingHeartRate, activeEnergy, bodyWeight, bmi, sleepAnalysis, biologicalSex, dateOfBirth]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isAuthorized = true
                    self.logger.info("HealthKit authorization granted")
                    self.fetchAllData()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Authorization failed."
                    self.logger.error("HealthKit authorization failed: \(self.errorMessage!)")
                }
            }
        }
    }
    
    func fetchAllData() {
        logger.info("Fetching all HealthKit data")
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
                    self.logger.error("Step count query failed: \(error.localizedDescription)")
                    self.stepCount = nil
                    return
                }
                if let sum = result?.sumQuantity() {
                    self.stepCount = sum.doubleValue(for: HKUnit.count())
                    self.logger.debug("Step count fetched: \(self.stepCount!)")
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
                    self.logger.error("Heart rate query failed: \(error.localizedDescription)")
                    self.heartRate = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.logger.debug("Heart rate fetched: \(self.heartRate!)")
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
                    self.logger.error("Resting heart rate query failed: \(error.localizedDescription)")
                    self.restingHeartRate = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.restingHeartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    self.logger.debug("Resting heart rate fetched: \(self.restingHeartRate!)")
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
                    self.logger.error("Active energy query failed: \(error.localizedDescription)")
                    self.activeEnergy = nil
                    return
                }
                if let sum = result?.sumQuantity() {
                    self.activeEnergy = sum.doubleValue(for: HKUnit.kilocalorie())
                    self.logger.debug("Active energy fetched: \(self.activeEnergy!)")
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
                    self.logger.error("Body weight query failed: \(error.localizedDescription)")
                    self.bodyWeight = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.bodyWeight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    self.logger.debug("Body weight fetched: \(self.bodyWeight!)")
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
                    self.logger.error("BMI query failed: \(error.localizedDescription)")
                    self.bmi = nil
                    return
                }
                if let sample = samples?.first as? HKQuantitySample {
                    self.bmi = sample.quantity.doubleValue(for: HKUnit.count())
                    self.logger.debug("BMI fetched: \(self.bmi!)")
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
                    self.logger.error("Sleep analysis query failed: \(error.localizedDescription)")
                    self.sleepHours = nil
                    return
                }
                let totalSleepSeconds = samples?.compactMap { sample -> Double? in
                    guard let sample = sample as? HKCategorySample, sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue else { return nil }
                    return sample.endDate.timeIntervalSince(sample.startDate)
                }.reduce(0, +) ?? 0
                self.sleepHours = totalSleepSeconds / 3600
                self.logger.debug("Sleep hours fetched: \(self.sleepHours!)")
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
                self.logger.debug("Biological sex fetched: \(self.biologicalSex ?? "nil")")
            }
        } catch {
            DispatchQueue.main.async {
                self.logger.error("Biological sex query failed: \(error.localizedDescription)")
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
                    self.logger.debug("Age fetched: \(self.age!)")
                }
            } else {
                DispatchQueue.main.async {
                    self.age = nil
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.logger.error("Date of birth query failed: \(error.localizedDescription)")
                self.age = nil
            }
        }
    }
}

extension HKAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .sharingDenied: return "Sharing Denied"
        case .sharingAuthorized: return "Sharing Authorized"
        @unknown default: return "Unknown"
        }
    }
}
