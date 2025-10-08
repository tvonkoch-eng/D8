//
//  BackendConfiguration.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation

enum Environment {
    case production
    case development
    case local
}

struct BackendConfiguration {
    static let current: Environment = {
        #if DEBUG
        return .development  // Use development in debug builds
        #else
        return .production    // Use production in release builds
        #endif
    }()
    
    static var baseURL: String {
        switch current {
        case .production:
            return "https://your-production-railway-url.railway.app"
        case .development:
            return "https://your-dev-railway-url.railway.app"
        case .local:
            return "http://localhost:8000"
        }
    }
    
    static var environmentName: String {
        switch current {
        case .production: return "Production"
        case .development: return "Development"
        case .local: return "Local"
        }
    }
}
