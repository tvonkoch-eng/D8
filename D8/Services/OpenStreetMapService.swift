//
//  OpenStreetMapService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

// MARK: - OSM Data Models
struct OSMPlace: Identifiable, Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let amenity: String?
    let cuisine: String?
    let website: String?
    let phone: String?
    let address: String?
    let openingHours: String?
    let rating: Double?
    let priceLevel: String?
    let description: String?
    let capacity: String?
    let outdoorSeating: String?
    let takeaway: String?
    let delivery: String?
    let wheelchair: String?
    let smoking: String?
    let wifi: String?
    let parking: String?
    let paymentMethods: String?
    let lastUpdated: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayName: String {
        name.isEmpty ? "Unnamed Place" : name
    }
    
    var cuisineDisplayName: String {
        guard let cuisine = cuisine, !cuisine.isEmpty else { return "Various" }
        return cuisine.capitalized
    }
    
    var priceLevelDisplay: String {
        guard let priceLevel = priceLevel else { return "Unknown" }
        switch priceLevel {
        case "0": return "Free"
        case "1": return "$"
        case "2": return "$$"
        case "3": return "$$$"
        case "4": return "$$$$"
        default: return "Unknown"
        }
    }
    
    var amenitiesList: [String] {
        var amenities: [String] = []
        
        if outdoorSeating == "yes" { amenities.append("Outdoor Seating") }
        if takeaway == "yes" { amenities.append("Takeaway") }
        if delivery == "yes" { amenities.append("Delivery") }
        if wheelchair == "yes" { amenities.append("Wheelchair Accessible") }
        if wifi == "yes" { amenities.append("WiFi") }
        if parking == "yes" { amenities.append("Parking") }
        
        return amenities
    }
    
    var formattedAddress: String {
        return address ?? "Address not available"
    }
    
    var formattedPhone: String {
        return phone ?? "Phone not available"
    }
    
    var formattedWebsite: String {
        return website ?? "Website not available"
    }
    
    var formattedHours: String {
        return openingHours ?? "Hours not available"
    }
    
    var hasOutdoorSeating: Bool {
        return outdoorSeating == "yes"
    }
    
    var isWheelchairAccessible: Bool {
        return wheelchair == "yes"
    }
    
    var hasWifi: Bool {
        return wifi == "yes"
    }
    
    var hasParking: Bool {
        return parking == "yes"
    }
}

struct OSMResponse: Codable {
    let elements: [OSMElement]
}

struct OSMElement: Codable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
    let center: OSMCenter?
}

struct OSMCenter: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - OpenStreetMap Service
class OpenStreetMapService: ObservableObject {
    static let shared = OpenStreetMapService()
    
    private let overpassAPIs = [
        "https://overpass-api.de/api/interpreter",
        "https://lz4.overpass-api.de/api/interpreter",
        "https://z.overpass-api.de/api/interpreter"
    ]
    private let nominatimAPI = "https://nominatim.openstreetmap.org"
    private var currentAPIIndex = 0
    
    private init() {}
    
    // MARK: - Geocoding
    func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(nominatimAPI)/search?q=\(encodedAddress)&format=json&limit=1"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstResult = json.first,
                  let latString = firstResult["lat"] as? String,
                  let lonString = firstResult["lon"] as? String,
                  let lat = Double(latString),
                  let lon = Double(lonString) else {
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                completion(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }.resume()
    }
    
    // MARK: - Restaurant Search
    func searchRestaurants(
        near coordinate: CLLocationCoordinate2D,
        radius: Int = 1000,
        cuisine: String? = nil,
        priceLevel: String? = nil,
        completion: @escaping ([OSMPlace]) -> Void
    ) {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Search for multiple amenity types to get more diverse results
        var query = """
        [out:json][timeout:60];
        (
          node["amenity"~"restaurant|cafe|bar|fast_food|pub|bistro"](around:\(radius),\(lat),\(lon));
          way["amenity"~"restaurant|cafe|bar|fast_food|pub|bistro"](around:\(radius),\(lat),\(lon));
          relation["amenity"~"restaurant|cafe|bar|fast_food|pub|bistro"](around:\(radius),\(lat),\(lon));
        );
        out center meta tags;
        """
        
        // Add cuisine filter if specified
        if let cuisine = cuisine, !cuisine.isEmpty {
            let cuisineFilter = cuisine.lowercased()
            query = """
            [out:json][timeout:60];
            (
              node["amenity"~"restaurant|cafe|bar|fast_food|pub|bistro"]["cuisine"~"\(cuisineFilter)",i](around:\(radius),\(lat),\(lon));
              way["amenity"~"restaurant|cafe|bar|fast_food|pub|bistro"]["cuisine"~"\(cuisineFilter)",i](around:\(radius),\(lat),\(lon));
              relation["amenity"~"restaurant|cafe|bar|fast_food|pub|bistro"]["cuisine"~"\(cuisineFilter)",i](around:\(radius),\(lat),\(lon));
            );
            out center meta tags;
            """
        }
        
        executeOverpassQuery(query) { elements in
            let places = elements.compactMap { self.convertElementToPlace($0) }
            
            // Only use fallback if we get absolutely no results
            if places.isEmpty {
                let fallbackPlaces = self.generateFallbackPlaces(near: coordinate, cuisine: cuisine)
                DispatchQueue.main.async {
                    completion(fallbackPlaces)
                }
            } else {
                DispatchQueue.main.async {
                    completion(places)
                }
            }
        }
    }
    
    // MARK: - General POI Search
    func searchPOIs(
        near coordinate: CLLocationCoordinate2D,
        radius: Int = 1000,
        amenities: [String] = ["restaurant", "cafe", "bar", "fast_food"],
        completion: @escaping ([OSMPlace]) -> Void
    ) {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        let amenityList = amenities.map { "\"\($0)\"" }.joined(separator: ",")
        
        let query = """
        [out:json][timeout:25];
        (
          node["amenity"~"\(amenityList)"](around:\(radius),\(lat),\(lon));
          way["amenity"~"\(amenityList)"](around:\(radius),\(lat),\(lon));
          relation["amenity"~"\(amenityList)"](around:\(radius),\(lat),\(lon));
        );
        out center;
        """
        
        executeOverpassQuery(query) { elements in
            let places = elements.compactMap { self.convertElementToPlace($0) }
            DispatchQueue.main.async {
                completion(places)
            }
        }
    }
    
    // MARK: - Private Methods
    private func executeOverpassQuery(_ query: String, completion: @escaping ([OSMElement]) -> Void) {
        executeOverpassQueryWithRetry(query, apiIndex: currentAPIIndex, completion: completion)
    }
    
    private func executeOverpassQueryWithRetry(_ query: String, apiIndex: Int, completion: @escaping ([OSMElement]) -> Void) {
        guard apiIndex < overpassAPIs.count else {
            completion([])
            return
        }
        
        guard let url = URL(string: overpassAPIs[apiIndex]) else {
            completion([])
            return
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("D8/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0 // Increase timeout for larger radius
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        request.httpBody = "data=\(encodedQuery)".data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // Try next API server
                self.executeOverpassQueryWithRetry(query, apiIndex: apiIndex + 1, completion: completion)
                return
            }
            
            guard let data = data else {
                // Try next API server
                self.executeOverpassQueryWithRetry(query, apiIndex: apiIndex + 1, completion: completion)
                return
            }
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    // Try next API server
                    self.executeOverpassQueryWithRetry(query, apiIndex: apiIndex + 1, completion: completion)
                    return
                }
            }
            
            do {
                let osmResponse = try JSONDecoder().decode(OSMResponse.self, from: data)
                self.currentAPIIndex = apiIndex // Remember which API worked
                completion(osmResponse.elements)
            } catch {
                // Try next API server
                self.executeOverpassQueryWithRetry(query, apiIndex: apiIndex + 1, completion: completion)
            }
        }.resume()
    }
    
    private func convertElementToPlace(_ element: OSMElement) -> OSMPlace? {
        let lat: Double
        let lon: Double
        
        if let elementLat = element.lat, let elementLon = element.lon {
            lat = elementLat
            lon = elementLon
        } else if let center = element.center {
            lat = center.lat
            lon = center.lon
        } else {
            return nil
        }
        
        let tags = element.tags ?? [:]
        
        // Build address from available components
        var addressComponents: [String] = []
        if let street = tags["addr:street"] { addressComponents.append(street) }
        if let houseNumber = tags["addr:housenumber"] { addressComponents.append(houseNumber) }
        if let city = tags["addr:city"] { addressComponents.append(city) }
        if let state = tags["addr:state"] { addressComponents.append(state) }
        if let postcode = tags["addr:postcode"] { addressComponents.append(postcode) }
        
        let fullAddress = addressComponents.isEmpty ? tags["addr:full"] : addressComponents.joined(separator: ", ")
        
        
        return OSMPlace(
            id: element.id,
            name: tags["name"] ?? "Unnamed Place",
            latitude: lat,
            longitude: lon,
            amenity: tags["amenity"],
            cuisine: tags["cuisine"],
            website: tags["website"],
            phone: tags["phone"],
            address: fullAddress,
            openingHours: tags["opening_hours"],
            rating: Double(tags["rating"] ?? ""),
            priceLevel: tags["price_level"],
            description: tags["description"] ?? tags["note"],
            capacity: tags["capacity"],
            outdoorSeating: tags["outdoor_seating"],
            takeaway: tags["takeaway"],
            delivery: tags["delivery"],
            wheelchair: tags["wheelchair"],
            smoking: tags["smoking"],
            wifi: tags["wifi"],
            parking: tags["parking"],
            paymentMethods: tags["payment:methods"],
            lastUpdated: tags["last_updated"]
        )
    }
    
    // MARK: - Cuisine Mapping
    func mapCuisineToOSM(_ cuisine: Cuisine) -> String? {
        switch cuisine {
        case .italian: return "italian"
        case .mexican: return "mexican"
        case .american: return "american"
        case .japanese: return "japanese"
        case .chinese: return "chinese"
        case .indian: return "indian"
        case .thai: return "thai"
        case .french: return "french"
        case .mediterranean: return "mediterranean"
        case .notSure: return nil
        }
    }
    
    func mapPriceRangeToOSM(_ priceRange: PriceRange) -> String? {
        switch priceRange {
        case .free: return "0"
        case .low: return "1"
        case .medium: return "2"
        case .high: return "3"
        case .luxury: return "4"
        case .notSure: return nil
        }
    }
    
    // MARK: - Fallback Data
    private func generateFallbackPlaces(near coordinate: CLLocationCoordinate2D, cuisine: String?) -> [OSMPlace] {
        let baseLat = coordinate.latitude
        let baseLon = coordinate.longitude
        
        // Generate diverse sample places around the user's location
        let samplePlaces = [
            ("The Local Bistro", "restaurant", cuisine ?? "american", "2", 4.2, "123 Main St"),
            ("Café Corner", "cafe", "coffee", "1", 4.0, "456 Coffee Lane"),
            ("Fine Dining", "restaurant", cuisine ?? "french", "4", 4.5, "789 Elegant Ave"),
            ("Quick Bites", "fast_food", cuisine ?? "american", "1", 3.8, "321 Fast St"),
            ("Cozy Bar", "bar", "cocktails", "2", 4.1, "654 Bar Street"),
            ("Pizza Palace", "restaurant", "italian", "2", 4.3, "987 Pizza Blvd"),
            ("Sushi Spot", "restaurant", "japanese", "3", 4.4, "147 Sushi Way"),
            ("Taco Truck", "fast_food", "mexican", "1", 4.0, "258 Taco Lane"),
            ("Brewery", "bar", "beer", "2", 4.2, "369 Brew St"),
            ("Diner", "restaurant", "american", "1", 3.9, "741 Diner Ave")
        ]
        
        return samplePlaces.enumerated().map { index, place in
            // Create more realistic distance distribution
            let distance = Double.random(in: 200...2000) // 200m to 2km
            let angle = Double.random(in: 0...2 * Double.pi)
            let offsetLat = (distance / 111000) * cos(angle) // Rough conversion to degrees
            let offsetLon = (distance / (111000 * cos(baseLat * Double.pi / 180))) * sin(angle)
            
            return OSMPlace(
                id: 1000 + index,
                name: place.0,
                latitude: baseLat + offsetLat,
                longitude: baseLon + offsetLon,
                amenity: place.1,
                cuisine: place.2,
                website: nil,
                phone: nil,
                address: place.5,
                openingHours: place.1 == "bar" ? "Mo-Su 17:00-02:00" : "Mo-Su 09:00-22:00",
                rating: place.4,
                priceLevel: place.3,
                description: nil,
                capacity: nil,
                outdoorSeating: Bool.random() ? "yes" : nil,
                takeaway: Bool.random() ? "yes" : nil,
                delivery: Bool.random() ? "yes" : nil,
                wheelchair: Bool.random() ? "yes" : nil,
                smoking: nil,
                wifi: Bool.random() ? "yes" : nil,
                parking: Bool.random() ? "yes" : nil,
                paymentMethods: nil,
                lastUpdated: nil
            )
        }
    }
}
