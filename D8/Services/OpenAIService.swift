//
//  OpenAIService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation

class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    // TODO: Replace with actual OpenAI API key
    private let apiKey = "sk-your-openai-api-key-here" // Replace with actual API key
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    // MARK: - Public Methods
    
    func generateRestaurantDetails(prompt: String) async throws -> String {
        // Check if API key is properly set
        guard apiKey != "sk-your-openai-api-key-here" && !apiKey.isEmpty else {
            throw OpenAIError.invalidAPIKey
        }
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [
                OpenAIMessage(role: "user", content: prompt)
            ],
            maxTokens: 1000,
            temperature: 0.7
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw OpenAIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = openAIResponse.choices.first?.message.content else {
                throw OpenAIError.noContent
            }
            return content
        } catch {
            throw OpenAIError.decodingError
        }
    }
}

// MARK: - OpenAI Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

// MARK: - OpenAI Errors

enum OpenAIError: Error, LocalizedError {
    case invalidAPIKey
    case invalidURL
    case encodingError
    case invalidResponse
    case decodingError
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "OpenAI API key is not configured. Please add your API key to OpenAIService.swift"
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .encodingError:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .decodingError:
            return "Failed to decode OpenAI response"
        case .noContent:
            return "No content in OpenAI response"
        }
    }
}
