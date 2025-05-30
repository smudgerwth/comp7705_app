//
//  InsurancePrediction.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//
import SwiftUI

struct InsurancePrediction: Codable {
    let base_premium: Double
    let discount_rate: String
    let final_premium: Double
    let health_assessment: String
    let health_score: Double
}
