//
//  PhoneWCSessionManager.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//
import Foundation
import WatchConnectivity

class PhoneWCSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = PhoneWCSessionManager() // Singleton pattern

    @Published var lastPredictionFromWatchRequest: InsurancePrediction?
    @Published var processingErrorForWatch: String?

    // Reference to the APIManager singleton
    private let apiManager = APIManager.shared

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            print("PhoneWCSessionManager: WCSession activation initiated.")
        } else {
            print("PhoneWCSessionManager: WCSession is not supported on this device (iPhone).")
        }
    }

    // MARK: - WCSessionDelegate Methods

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("PhoneWCSessionManager: WCSession (iPhone) activation failed: \(error.localizedDescription)")
            // Optionally, update UI or state
            // DispatchQueue.main.async { self.processingErrorForWatch = "WCSession activation failed: \(error.localizedDescription)" }
            return
        }
        print("PhoneWCSessionManager: WCSession (iPhone) activated with state: \(activationState.rawValue)")
        // You can add logic here to handle different activation states if needed.
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            // Clear previous states for this new message
            self.processingErrorForWatch = nil
            self.lastPredictionFromWatchRequest = nil
        }
        print("PhoneWCSessionManager: iPhone received message: \(message)")

        guard let requestType = message["requestType"] as? String, requestType == "getInsurancePrediction" else {
            print("PhoneWCSessionManager: Unknown request type or missing 'requestType' field.")
            replyHandler(["error": "Unknown request type (received by iPhone)."])
            return
        }

        // Extract necessary data from the message payload
        guard let age = message["age"] as? Int,
              let bmi = message["bmi"] as? Double,
              let sex = message["sex"] as? Int,
              let smoker = message["smoker"] as? Int,
              let heartRate = message["heartRate"] as? Double,
              let steps = message["steps"] as? Double else {
            let errorMessage = "Missing necessary parameters in the message from Apple Watch."
            DispatchQueue.main.async {
                self.processingErrorForWatch = errorMessage
            }
            replyHandler(["error": "Missing necessary parameters (iPhone received)."])
            return
        }

        let apiPayload: [String: Any] = [
            "age": age, "bmi": bmi, "sex": sex, "smoker": smoker, "heartRate": heartRate, "steps": steps
        ]

        // Use APIManager to fetch the insurance prediction
        apiManager.fetchInsurancePrediction(payload: apiPayload) { result in
            switch result {
            case .success(let prediction):
                DispatchQueue.main.async {
                    self.lastPredictionFromWatchRequest = prediction
                }
                // Encode the successful prediction object to Data to send back to the watch
                do {
                    let encoder = JSONEncoder()
                    let predictionData = try encoder.encode(prediction)
                    replyHandler(["predictionData": predictionData])
                } catch {
                    // This error is about encoding the successful prediction for the reply
                    let encodingErrorMsg = "Failed to encode prediction for watch reply: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        self.processingErrorForWatch = encodingErrorMsg
                    }
                    replyHandler(["error": encodingErrorMsg])
                }
                
            case .failure(let apiError): // This is APIError from APIManager
                let errorMessage = apiError.localizedDescription
                DispatchQueue.main.async {
                    self.processingErrorForWatch = errorMessage
                }
                replyHandler(["error": errorMessage])
            }
        }
    }

    /**
     * This method is REQUIRED on iOS for WCSessionDelegate conformance.
     * It is called when the state of the paired Apple Watch changes.
     */
    func sessionWatchStateDidChange(_ session: WCSession) {
        print("PhoneWCSessionManager: sessionWatchStateDidChange.")
        print("PhoneWCSessionManager: Paired Watch State - isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled), isReachable: \(session.isReachable)")
        // Add any logic needed to react to changes in the paired watch's state.
    }

    // MARK: - Deprecated WCSessionDelegate Methods
    // These are included because your environment/SDK target seems to require them.
    // If you upgrade your target SDKs in the future, these might cause errors
    // indicating they are unavailable and would then need to be removed.

    /**
     * Called when the session becomes inactive.
     * Deprecated in newer iOS versions but may be required by your project's target SDK.
     */
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("PhoneWCSessionManager: WCSession (iPhone) did become inactive.")
        // Optional: Add custom logic if your app needs to handle this for older OS versions.
    }

    /**
     * Called when the session deactivates.
     * Deprecated in newer iOS versions but may be required by your project's target SDK.
     * It's crucial to re-activate the session when this is called if targeting older OS versions.
     */
    func sessionDidDeactivate(_ session: WCSession) {
        print("PhoneWCSessionManager: WCSession (iPhone) did deactivate. Reactivating session...")
        WCSession.default.activate()
    }
}
