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
                    }
                    .listStyle(GroupedListStyle())
                }
                
                Toggle("Are you a smoker?", isOn: $isSmoker)
                    .padding(.horizontal)
                
                Button(action: {
                    print("Submit button tapped. Smoker status: \(isSmoker)")
                    print("Health Data: Steps: \(healthKitManager.stepCount ?? 0), Sex: \(healthKitManager.biologicalSex ?? "N/A"), Age: \(healthKitManager.age ?? 0)")
                }) {
                    Text("Submit")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .onAppear {
                healthKitManager.checkAuthorizationStatus()
            }
            .alert(isPresented: $showHealthKitError) {
                Alert(
                    title: Text("HealthKit Error"),
                    message: Text(healthKitManager.errorMessage ?? "HealthKit is not available or an error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarTitleDisplayMode(.inline)
        }
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
