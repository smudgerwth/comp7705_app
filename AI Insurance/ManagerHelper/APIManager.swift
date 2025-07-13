//
//  APIManager.swift
//  AI Insurance
//
//  Created by Chuen on 30/5/2025.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case encodingFailed(Error)
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingFailed(Error, Data?) // Include data for debugging
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL was invalid."
        case .requestFailed(let error):
            return "The network request failed: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode the request payload: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let statusCode, _):
            return "Server returned an HTTP error: \(statusCode)."
        case .decodingFailed(let error, _):
            return "Failed to decode the server response: \(error.localizedDescription)"
        case .noData:
            return "No data was received from the server."
        }
    }
}

class APIManager {
    static let shared = APIManager() // Singleton instance, or you can inject it

    private init() {} // Private initializer for singleton

    func fetchInsurancePrediction(payload: [String: Any], completion: @escaping (Result<InsurancePrediction, APIError>) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5050/predict") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(.encodingFailed(error)))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.httpError(statusCode: httpResponse.statusCode, data: data)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            // --- Start of new code ---
            // Print the data as a dictionary for debugging
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Received dictionary: \(jsonObject)")
                }
            } catch {
                print("Failed to serialize data to dictionary: \(error.localizedDescription)")
            }
            // --- End of new code ---

            do {
                let decoder = JSONDecoder()
                let prediction = try decoder.decode(InsurancePrediction.self, from: data)
                completion(.success(prediction))
            } catch {
                completion(.failure(.decodingFailed(error, data)))
            }
        }.resume()
    }
}
