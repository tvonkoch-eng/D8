//
//  RestaurantDetails.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation

struct RestaurantDetails: Codable, Identifiable {
    let id: String
    let restaurantId: String // Unique identifier based on address
    let name: String
    let description: String
    let hours: [String]
    let additionalInfo: String
    let lastUpdated: Date
    
    init(restaurantId: String, name: String, description: String, hours: [String], additionalInfo: String) {
        self.id = restaurantId
        self.restaurantId = restaurantId
        self.name = name
        self.description = description
        self.hours = hours
        self.additionalInfo = additionalInfo
        self.lastUpdated = Date()
    }
}
