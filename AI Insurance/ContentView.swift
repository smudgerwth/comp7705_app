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
    @State private var showHealthKitError = false
    @State private var predictedPremium: Double? // Store predicted premium
    @State private var isLoading = false // Loading state for server request
    @State private var serverError: String? // Server error message
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("AI Insurance")
                    .font(.largeTitle)
                    .padding()
                
                if !healthKitManager.isAuthorized {
                    Button(action: {
                        if HKHealthStore.isHealthDataAvailable() {
                            healthKitManager.requestAuthorization()
                        } else {
                            showHealthKitError = true
                        }
                    }) {
                        Text("Request HealthKit Permission")
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
                        Section(header: Text("Health Data")) {
                            HealthDataRow(label: "Steps Today", value: healthKitManager.stepCount, unit: "steps", format: "%.0f")
                            HealthDataRow(label: "Heart Rate", value: healthKitManager.heartRate, unit: "bpm", format: "%.0f")
                            HealthDataRow(label: "Resting Heart Rate", value: healthKitManager.restingHeartRate, unit: "bpm", format: "%.0f")
                            HealthDataRow(label: "Active Energy Today", value: healthKitManager.activeEnergy, unit: "kcal", format: "%.0f")
                            HealthDataRow(label: "Body Weight", value: healthKitManager.bodyWeight, unit: "kg", format: "%.1f")
                            HealthDataRow(label: "BMI", value: healthKitManager.bmi, unit: "", format: "%.1f")
                            HealthDataRow(label: "Sleep Last Night", value: healthKitManager.sleepHours, unit: "hours", format: "%.1f")
                            Text("Biological Sex: \(healthKitManager.biologicalSex ?? "N/A")")
                            Text("Age: \(healthKitManager.age != nil ? String(healthKitManager.age!) : "N/A")")
                        }
                        if let premium = predictedPremium {
                            Section(header: Text("Insurance Prediction")) {
                                Text("Predicted Premium: $\(String(format: "%.2f", premium))")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                }
                
                Toggle("Are you a smoker?", isOn: $isSmoker)
                    .padding(.horizontal)
                
                Button(action: {
                    submitToServer()
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
                    message: Text(healthKitManager.errorMessage ?? serverError ?? "An error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func submitToServer() {
        // Use HealthKit data if available, otherwise defaults
        let age = healthKitManager.age ?? 30
        let bmi = healthKitManager.bmi ?? 25.0
        let sexString = healthKitManager.biologicalSex?.lowercased()
        let sex: Int = (sexString == "female") ? 1 : 0 // Default to 1 (female) if unavailable
        let smoker: Int = isSmoker ? 1 : 0
        
        // Prepare JSON payload
        let payload: [String: Any] = [
            "age": age,
            "bmi": bmi,
            "sex": sex,
            "smoker": smoker
        ]
        
        guard let url = URL(string: "http://127.0.0.1:5050/predict") else {
            serverError = "Invalid server URL."
            showHealthKitError = true
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            serverError = "Failed to encode JSON: \(error.localizedDescription)"
            showHealthKitError = true
            return
        }
        
        isLoading = true
        predictedPremium = nil
        serverError = nil
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.serverError = "Server request failed: \(error.localizedDescription)"
                    self.showHealthKitError = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.serverError = "Server returned an error: \(response.debugDescription)"
                    self.showHealthKitError = true
                    return
                }
                
                guard let data = data else {
                    self.serverError = "No data received from server."
                    self.showHealthKitError = true
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let premium = json["predicted_premium"] as? Double {
                        self.predictedPremium = premium
                    } else {
                        self.serverError = "Invalid response format from server."
                        self.showHealthKitError = true
                    }
                } catch {
                    self.serverError = "Failed to parse server response: \(error.localizedDescription)"
                    self.showHealthKitError = true
                }
            }
        }.resume()
    }
}

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
