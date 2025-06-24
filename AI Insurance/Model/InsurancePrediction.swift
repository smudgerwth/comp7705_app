//
//  InsurancePrediction.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//
import SwiftUI

import Foundation

// Struct for individual plan details
struct InsurancePlan: Codable {
    let certificationNo: String
    let companyName: String
    let planDocUrl: String
    let planName: String
    let premium: Double

    // Custom coding keys to match JSON snake_case
    enum CodingKeys: String, CodingKey {
        case certificationNo = "certification-no"
        case companyName = "company-name"
        case planDocUrl = "plan-doc-url"
        case planName = "plan-name"
        case premium
    }
}

// Struct for recommendation_list
struct RecommendationList: Codable {
    let error: String?
    let plans: [InsurancePlan]
}

// Main struct for the insurance prediction
struct InsurancePrediction: Codable {
    let basePremium: Double
    let discountRate: String
    let finalPremium: Double
    let healthAssessment: String
    let healthScore: Double
    let recommendationList: RecommendationList

    // Custom coding keys to match JSON snake_case
    enum CodingKeys: String, CodingKey {
        case basePremium = "base_premium"
        case discountRate = "discount_rate"
        case finalPremium = "final_premium"
        case healthAssessment = "health_assessment"
        case healthScore = "health_score"
        case recommendationList = "recommendation_list"
    }
}
