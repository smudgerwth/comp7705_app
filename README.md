# **AI Health Insurance \- iOS & watchOS App**

This repository contains the source code for the "AI Insurance" iOS and Apple Watch application. The app securely reads a user's health data via HealthKit, sends it to a backend AI model for analysis, and displays a personalized insurance premium prediction directly on the Apple Watch.

![watch demo](https://github.com/user-attachments/assets/326a1e83-e803-4de7-ba66-c16387360069) 

 ![Simulator Screen Recording - iPhone 16 Pro Max Paired - 2025-07-13 at 16 28 16](https://github.com/user-attachments/assets/d59663e6-7f91-4bb8-92d2-9275b24518db)


## **Project Overview**

The application provides a seamless user experience, leveraging the power of both the iPhone and Apple Watch. The watchOS app serves as the primary user interface for data collection and submission, while the companion iOS app acts as a bridge to communicate with the backend server, ensuring efficient processing and battery life management.

## **Features**

* **Deep HealthKit Integration**: Securely reads a wide range of health metrics, including monthly averages for steps, heart rate, active energy, weight, and sleep, providing a holistic view of the user's health trends.  
* **watchOS First Interface**: The entire user journey, from granting permissions to viewing the final prediction, is handled on the Apple Watch.  
* **Real-time Watch-to-Phone Communication**: Utilizes the Watch Connectivity framework to send health data from the watch to the phone for processing and receive the prediction results back in real-time.  
* **Detailed Prediction Display**: Clearly presents the AI-driven analysis, including a health score, base vs. final premium, discount/surcharge rate, and a list of recommended insurance plans.  
* **Modern SwiftUI UI**: A clean, responsive, and intuitive user interface built entirely with SwiftUI.  
* **Robust Error Handling**: Provides clear user-facing alerts for issues related to HealthKit permissions, network requests, or watch-phone connectivity.

## **App Architecture & Data Flow**

The application is architected to separate concerns, with dedicated managers for data collection (HealthKit), communication (Watch Connectivity), and network requests (API). The data flows in a round-trip from the watch to the phone and back.

<img width="907" height="442" alt="螢幕截圖 2025-07-13 下午3 32 11" src="https://github.com/user-attachments/assets/27f54a81-ec0f-47ee-90a3-2e7f6e8e0050" />


1. **Initiation (Watch)**: The user opens the app on their Apple Watch. HealthKitManager requests permissions and fetches 30-day average health data.  
2. **Data Transmission (Watch \-\> Phone)**: The user taps "Submit". ContentView gathers the data from HealthKitManager, and WatchWCSessionManager sends it to the paired iPhone.  
3. **Processing (Phone)**: The PhoneWCSessionManager on the iPhone receives the data. It invokes the APIManager to make a POST request to the backend server.  
4. **Response (Phone \-\> Watch)**: The APIManager receives the prediction from the server. PhoneWCSessionManager sends this result back to the watch as a reply.  
5. **Display (Watch)**: WatchWCSessionManager on the watch receives the reply, decodes the prediction data, and the ContentView UI updates to display the results.

## **Core Components**

* HealthKitManager.swift: A singleton class responsible for all interactions with the HealthKit store. It handles authorization and fetches all required health metrics.  
* WatchWCSessionManager.swift: Manages WCSession on the watchOS app. Responsible for sending data to the phone and handling the reply.  
* PhoneWCSessionManager.swift: Manages WCSession on the iOS app. Listens for messages from the watch, delegates network requests to the APIManager, and sends the result back.  
* APIManager.swift: A singleton class on the iOS app that handles all network communication with the backend prediction server.  
* InsurancePrediction.swift: A Codable data model that represents the JSON structure of the API response, used for easy decoding.  
* WatchContentView.swift: The primary SwiftUI view for the watchOS app, displaying all user-facing information and controls.


## **Setup and Build**

To build and run this project, you will need:

* macOS with Xcode installed.  
* An Apple Developer account for code signing.  
* A physical iPhone and Apple Watch are highly recommended for testing HealthKit and Watch Connectivity features.

### **Steps:**

1. **Clone the Repository**  
   git clone https://github.com/smudgerwth/comp7705\_app.git  
   cd comp7705\_app

2. Open in Xcode  
   Open the .xcodeproj or .xcworkspace file.

3. **Configure Signing & Capabilities**  
   * In the Project Navigator, select the project file.  
   * For both the AI Insurance (iOS) and AI Insurance Watch Watch App (watchOS) targets, go to the "Signing & Capabilities" tab.  
   * Select your development team from the "Team" dropdown. Xcode may require you to change the "Bundle Identifier" to something unique.  
   * Ensure the "HealthKit" capability is added to both targets.

4. **Build and Run**  
   * Select the AI Insurance Watch scheme in Xcode.  
   * Choose your physical Apple Watch (or a simulator) as the run destination.  
   * Click the "Run" button (▶).

## **File Structure**

A brief overview of the key source files in the project:

AI Insurance/  
├── AI\_InsuranceApp.swift           \# iOS App entry point  
├── ContentView.swift               \# Main SwiftUI View (used by watchOS)  
├── HealthKitManager.swift          \# Handles HealthKit data fetching  
├── APIManager.swift                \# (iOS) Handles network calls to the backend  
├── PhoneWCSessionManager.swift     \# (iOS) Manages watch connectivity  
├── InsurancePrediction.swift       \# Codable data model for API response  
└── AI Insurance Watch Watch App/  
    ├── AI\_Insurance\_WatchApp.swift \# watchOS App entry point  
    └── WatchWCSessionManager.swift \# (watchOS) Manages watch connectivity  


## **License**

This project is licensed under the [MIT License](https://www.google.com/search?q=LICENSE).
