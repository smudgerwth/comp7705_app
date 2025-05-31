//
//  ContentView.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var wcSessionManager = WatchWCSessionManager.shared // Using the WatchConnectivity manager

    @State private var isSmoker = false
    
    // State variables to control alert presentation and its message
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    Text("AI Insurance")
                        .font(.headline)
                        .padding(.top)

                    if !healthKitManager.isAuthorized {
                        Button(action: {
                            if HKHealthStore.isHealthDataAvailable() {
                                healthKitManager.requestAuthorization()
                            } else {
                                // Directly set alertMessage and showAlert for HealthKit unavailability
                                self.alertMessage = "HealthKit is not available on this device."
                                self.showAlert = true
                            }
                        }) {
                            Text("Request Health Data Permission")
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

                    if healthKitManager.isAuthorized {
                        Section(header: Text("Health Data").font(.caption2).padding(.top)) {
                            HealthDataRow(label: "Steps", value: healthKitManager.stepCount, unit: "steps", format: "%.0f")
                            HealthDataRow(label: "Heart Rate", value: healthKitManager.heartRate, unit: "bpm", format: "%.0f")
                            HealthDataRow(label: "Active Energy", value: healthKitManager.activeEnergy, unit: "kcal", format: "%.0f")
                            HealthDataRow(label: "Weight", value: healthKitManager.bodyWeight, unit: "kg", format: "%.1f")
                            HealthDataRow(label: "BMI", value: healthKitManager.bmi, unit: "", format: "%.1f")
                            HealthDataRow(label: "Sleep", value: healthKitManager.sleepHours, unit: "hrs", format: "%.1f")
                            Text("Biological Sex: \(healthKitManager.biologicalSex ?? "N/A")").font(.footnote)
                            Text("Age: \(healthKitManager.age != nil ? String(healthKitManager.age!) : "N/A")").font(.footnote)
                        }
                        .padding(.horizontal)


                        if let prediction = wcSessionManager.insurancePrediction { // Get prediction from wcSessionManager
                            Section(header: Text("Insurance Prediction").font(.caption2).padding(.top)) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("Base Premium:").font(.caption)
                                        Spacer()
                                        Text("$\(prediction.base_premium, specifier: "%.2f")").font(.caption)
                                    }
                                    HStack {
                                        Text("Health Score:").font(.caption)
                                        Spacer()
                                        Text("\(prediction.health_score, specifier: "%.1f")/100").font(.caption)
                                            .foregroundColor(getHealthScoreColor(prediction.health_score))
                                    }
                                    HStack {
                                        Text("Discount Rate:").font(.caption)
                                        Spacer()
                                        Text(prediction.discount_rate).font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    Divider()
                                    HStack {
                                        Text("Final Premium:").font(.footnote).bold()
                                        Spacer()
                                        Text("$\(prediction.final_premium, specifier: "%.2f")").font(.footnote).bold()
                                            .foregroundColor(.green)
                                    }
                                    Text(prediction.health_assessment)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(5)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(5)
                            }
                            .padding(.horizontal)
                        }
                    }

                    Toggle("Are you a smoker?", isOn: $isSmoker)
                        .font(.footnote)
                        .padding(.horizontal)

                    Button(action: {
                        submitViaWatchConnectivity() // Call this function to send data via WC
                    }) {
                        Text(wcSessionManager.isLoading ? "Submitting..." : "Submit") // Get loading state from wcSessionManager
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(wcSessionManager.isLoading ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(wcSessionManager.isLoading || !healthKitManager.isAuthorized) // Disable if loading or not authorized
                    .padding(.horizontal)
                    .padding(.bottom)

                } // End VStack
            } // End ScrollView
            .onAppear {
                healthKitManager.checkAuthorizationStatus()
                // Fetch data if authorized
                if healthKitManager.isAuthorized {
                    healthKitManager.fetchAllData()
                }
            }
            // Listen for changes in error messages from both managers
            .onChange(of: wcSessionManager.errorMessage) { oldValue, newValue in
                if let msg = newValue, !msg.isEmpty {
                    self.alertMessage = msg
                    self.showAlert = true
                }
            }
            .onChange(of: healthKitManager.errorMessage) { oldValue, newValue in
                if let msg = newValue, !msg.isEmpty {
                    // Only show HealthKit error if WCSession error isn't already being shown
                    // or if the WCSession error was different.
                    if !self.showAlert || self.alertMessage != wcSessionManager.errorMessage {
                        self.alertMessage = msg
                        self.showAlert = true
                    }
                }
            }
            .alert(isPresented: $showAlert) { // Use the new @State variable for alert presentation
                Alert(
                    title: Text("Notice"),
                    message: Text(self.alertMessage), // Display the stored error message
                    dismissButton: .default(Text("OK")) {
                        // Clear the error source that triggered the alert
                        if self.alertMessage == wcSessionManager.errorMessage {
                            wcSessionManager.errorMessage = nil
                        }
                        if self.alertMessage == healthKitManager.errorMessage {
                            healthKitManager.errorMessage = nil
                        }
                        self.alertMessage = "" // Clear the current alert message
                    }
                )
            }
            .navigationTitle("Insurance")
            .navigationBarTitleDisplayMode(.inline)
        } // End NavigationView
    }

    private func getHealthScoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return Color(red: 0.2, green: 0.8, blue: 0.2) // A slightly different green
        case 60..<75: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private func submitViaWatchConnectivity() {
        // Prepare payload, similar to before
        let age = healthKitManager.age ?? 18
        let bmi = healthKitManager.bmi ?? 25.0
        let sexString = healthKitManager.biologicalSex?.lowercased()
        let sex: Int = (sexString == "female") ? 1 : 0
        let smoker: Int = isSmoker ? 1 : 0
        let heartRate = healthKitManager.heartRate ?? 70.0
        let steps = healthKitManager.stepCount ?? 10000.0

        let payload: [String: Any] = [
            "age": age,
            "bmi": bmi,
            "sex": sex,
            "smoker": smoker,
            "heartRate": heartRate,
            "steps": steps,
            "requestType": "getInsurancePrediction" // Request type identifier for iPhone to recognize
        ]
        
        // Clear HealthKitManager's error message as this operation is via WCSession
        healthKitManager.errorMessage = nil
        
        wcSessionManager.sendDataToPhone(payload: payload)
    }
}

// This struct is used to display health data rows.
// Ensure it's defined or accessible in your Watch App target.
struct HealthDataRow: View {
    let label: String
    let value: Double?
    let unit: String
    let format: String

    var body: some View {
        HStack {
            Text(label).font(.footnote)
            Spacer()
            Text(value != nil ? String(format: format, value!) + " \(unit)" : "N/A")
                .font(.footnote)
                .foregroundColor(value != nil ? .primary : .gray)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
