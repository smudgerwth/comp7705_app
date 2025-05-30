//
//  AI_InsuranceApp.swift
//  AI Insurance
//
//  Created by Aidan Wong on 28/5/2025.
//

import SwiftUI

@main
struct AI_InsuranceApp: App {
    
    init() {
        _ = PhoneWCSessionManager.shared
        print("AI_InsuranceApp: PhoneWCSessionManager shared instance initialized.")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
