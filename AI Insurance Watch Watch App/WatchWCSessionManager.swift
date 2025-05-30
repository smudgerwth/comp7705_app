//
//  WatchWCSessionManager.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//

import Foundation
import WatchConnectivity

class WatchWCSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchWCSessionManager() // Singleton pattern

    @Published var isLoading: Bool = false
    @Published var insurancePrediction: InsurancePrediction?
    @Published var errorMessage: String?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            print("WCSession is not supported on this device.")
            DispatchQueue.main.async {
                self.errorMessage = "Watch Connectivity is not supported on this device."
            }
        }
    }

    // MARK: - WCSessionDelegate Methods

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.errorMessage = "WCSession (Watch) activation failed: \(error.localizedDescription)"
                print("WCSession (Watch) activation failed: \(error.localizedDescription)")
                return
            }
            print("WCSession (Watch) activated with state: \(activationState.rawValue)")
            if activationState != .activated {
                self.errorMessage = "WCSession (Watch) not successfully activated. State: \(activationState.rawValue)"
            }
        }
    }

    // MARK: - Public Methods

    func sendDataToPhone(payload: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            DispatchQueue.main.async {
                self.errorMessage = "WCSession (Watch) is not activated."
                self.isLoading = false // Ensure isLoading is reset
            }
            return
        }

        guard WCSession.default.isReachable else {
            DispatchQueue.main.async {
                self.errorMessage = "iPhone is not reachable. Please ensure the app on iPhone is installed and running."
                self.isLoading = false // Ensure isLoading is reset
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.insurancePrediction = nil // Clear previous prediction
            self.errorMessage = nil      // Clear previous error
        }

        WCSession.default.sendMessage(payload, replyHandler: { response in
            DispatchQueue.main.async {
                self.isLoading = false
                if let errorMsg = response["error"] as? String {
                    self.errorMessage = "Error from iPhone: \(errorMsg)"
                } else if let responseData = response["predictionData"] as? Data {
                    do {
                        let decoder = JSONDecoder()
                        self.insurancePrediction = try decoder.decode(InsurancePrediction.self, from: responseData)
                    } catch {
                        self.errorMessage = "Failed to parse response from iPhone: \(error.localizedDescription)"
                    }
                } else {
                    self.errorMessage = "Received unknown response format from iPhone."
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to send message to iPhone: \(error.localizedDescription)"
            }
        })
    }
}
