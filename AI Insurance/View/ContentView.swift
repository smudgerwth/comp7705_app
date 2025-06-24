//
//  ContentView.swift
//  AI Insurance
//
//  Created by Aidan Wong on 28/5/2025.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isSmoker = false
    @State private var showHealthKitError = false // Used for HealthKit specific errors or general alerts
    @State private var insurancePrediction: InsurancePrediction?
    @State private var isLoading = false // Loading state for server request
    @State private var serverError: String? // To display error messages in the alert
    private let apiManager = APIManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("AI Insurance Recommender")
                    .font(.largeTitle)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)

                if !healthKitManager.isAuthorized {
                    Button(action: {
                        if HKHealthStore.isHealthDataAvailable() {
                            healthKitManager.requestAuthorization()
                        } else {
                            // This error is specific to HealthKit availability on device
                            self.serverError = "HealthKit is not available on this device."
                            self.showHealthKitError = true
                        }
                    }) {
                        Text("Sync Health Data")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                if healthKitManager.isAuthorized {
                    List {
                        if insurancePrediction == nil {
                            Section(header: Text("Health Data")) {
                                HealthDataRow(label: "Steps", value: healthKitManager.stepCount, unit: "steps", format: "%.0f")
                                HealthDataRow(label: "Heart Rate", value: healthKitManager.heartRate, unit: "bpm", format: "%.0f")
                                HealthDataRow(label: "Active Energy", value: healthKitManager.activeEnergy, unit: "kcal", format: "%.0f")
                                HealthDataRow(label: "Body Weight", value: healthKitManager.bodyWeight, unit: "kg", format: "%.1f")
                                HealthDataRow(label: "BMI", value: healthKitManager.bmi, unit: "", format: "%.1f")
                                HealthDataRow(label: "Sleep", value: healthKitManager.sleepHours, unit: "hours", format: "%.1f")
                                Text("Biological Sex: \(healthKitManager.biologicalSex ?? "N/A")")
                                Text("Age: \(healthKitManager.age != nil ? String(healthKitManager.age!) : "N/A")")
                            }
                        }
                        if let prediction = insurancePrediction {
                            Section(header: Text("Insurance Prediction")) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Base Premium:")
                                        Spacer()
                                        Text("$\(prediction.basePremium, specifier: "%.2f")")
                                    }
                                    
                                    HStack {
                                        Text("Health Score:")
                                        Spacer()
                                        Text("\(prediction.healthScore, specifier: "%.1f")/100")
                                            .foregroundColor(getHealthScoreColor(prediction.healthScore))
                                    }
                                    
                                    HStack {
                                        Text("Discount Rate:")
                                        Spacer()
                                        Text(prediction.discountRate)
                                            .foregroundColor(.green)
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Text("Final Premium:")
                                            .font(.headline)
                                        Spacer()
                                        Text("$\(prediction.finalPremium, specifier: "%.2f")")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text(prediction.healthAssessment)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    // Recommendation List
                                    Divider()
                                    
                                    Text("Recommended Plans:")
                                        .font(.headline)
                                        .padding(.top, 4)
                                    
                                    if prediction.recommendationList.error != nil {
                                        Text("Error loading recommendations")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                    } else if prediction.recommendationList.plans.isEmpty {
                                        Text("No plans available")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    } else {
                                        ForEach(prediction.recommendationList.plans, id: \.certificationNo) { plan in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(plan.planName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                
                                                Text(plan.companyName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                HStack {
                                                    Text("Premium:")
                                                    Text(String(format: "$%.2f", plan.premium))
                                                        .foregroundColor(.green)
                                                }
                                                .font(.caption)
                                                
                                                Link("View Plan Details", destination: URL(string: plan.planDocUrl)!)
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                            .padding(.vertical, 4)
                                            Divider()
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                }
                
                Toggle("Are you a smoker?", isOn: $isSmoker)
                    .padding(.horizontal)
                
                Button(action: {
                    if !healthKitManager.isAuthorized {
                        // authorize HealthKit if not already done
                        healthKitManager.requestAuthorization()
                    }
                    submitToServerWithAPIManager() // Call the refactored method
                }) {
                    Text(isLoading ? "Submitting..." : "Submit")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isLoading ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .onAppear {
                healthKitManager.checkAuthorizationStatus()
            }
            .alert(isPresented: $showHealthKitError) {
                Alert(
                    title: Text("Error"),
                    // Display HealthKitManager's error first if available, then serverError.
                    message: Text(healthKitManager.errorMessage ?? serverError ?? "An unknown error occurred."),
                    dismissButton: .default(Text("OK")) {
                        // Reset errors when alert is dismissed
                        healthKitManager.errorMessage = nil
                        serverError = nil
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                if healthKitManager.isAuthorized {
                    healthKitManager.fetchAllData()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func getHealthScoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case 60..<75: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    // Renamed the submit function to reflect it's using APIManager
    private func submitToServerWithAPIManager() {
        // Use HealthKit data if available, otherwise defaults
        let age: Int = healthKitManager.age ?? 18
        let bmi: Double = healthKitManager.bmi ?? 25.0
        let sexString = healthKitManager.biologicalSex?.lowercased()
        let sex: Int = (sexString == "female") ? 1 : 0 // Default to 0 (male) as per original logic (or 1 for female)
        let smoker: Int = isSmoker ? 1 : 0
        let heartRate: Double = healthKitManager.heartRate ?? 70.0 // Using Double for consistency with payload if needed
        let steps: Double = healthKitManager.stepCount ?? 10000.0 // Using Double
        let sleepHours: Double = healthKitManager.sleepHours ?? 0.0

        // Prepare JSON payload
        let payload: [String: Any] = [
            "age": age,
            "bmi": bmi,
            "sex": sex,
            "smoker": smoker,
            "heartRate": heartRate,
            "steps": steps,
            "sleepHours": sleepHours
        ]
        
        isLoading = true
        insurancePrediction = nil // Clear previous prediction
        serverError = nil         // Clear previous server error
        healthKitManager.errorMessage = nil // Clear HealthKit error too

        apiManager.fetchInsurancePrediction(payload: payload) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let prediction):
                    self.insurancePrediction = prediction
                case .failure(let error):
                    self.serverError = error.localizedDescription // Use localizedDescription from APIError
                    self.showHealthKitError = true // Re-use this state to show the alert
                    
                    // For debugging specific API errors:
                    
                    switch error {
                    case .decodingFailed(_, let data):
                        if let data = data, let text = String(data: data, encoding: .utf8) {
                            print("Decoding failed. Received data: \(text)")
                        }
                    case .httpError(_, let data):
                        if let data = data, let text = String(data: data, encoding: .utf8) {
                            print("HTTP error. Received data: \(text)")
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
}

// HealthDataRow struct remains the same
struct HealthDataRow: View {
    let label: String
    let value: Double?
    let unit: String
    let format: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value != nil ? String(format: format, value!) + " \(unit)" : "N/A")
                .foregroundColor(value != nil ? .primary : .gray)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
