//
//  LocationManager.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var permissionCallback: ((Bool) -> Void)?
    private var locationCallback: ((CLLocationCoordinate2D?) -> Void)?
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Cache location to avoid repeated API calls
    private var cachedLocation: CLLocationCoordinate2D?
    private var lastLocationUpdate: Date?
    private let locationCacheTimeout: TimeInterval = 300 // 5 minutes
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10.0
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        permissionCallback = completion
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Note: The callback will be called in didChangeAuthorization
        case .denied, .restricted:
            completion(false)
        case .authorizedWhenInUse, .authorizedAlways:
            completion(true)
        @unknown default:
            completion(false)
        }
    }
    
    func checkCurrentPermissionStatus() -> Bool {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
    
    func refreshPermissionStatus() {
        // Force refresh the authorization status
        let newStatus = locationManager.authorizationStatus
        authorizationStatus = newStatus
    }
    
    func getCurrentLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // Check if we have a cached location that's still valid
        if let cached = cachedLocation,
           let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < locationCacheTimeout {
            completion(cached)
            return
        }
        
        locationCallback = completion
        
        // Check authorization status first (this is safe on main thread)
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            completion(nil)
            return
        }
        
        // Move location services check to background queue to avoid UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            guard CLLocationManager.locationServicesEnabled() else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Request location on background queue
            self.locationManager.requestLocation()
        }
        
        // Add timeout mechanism - increased to 15 seconds for better reliability
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if self.locationCallback != nil {
                self.locationCallback?(nil)
                self.locationCallback = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionCallback?(true)
        case .denied, .restricted:
            permissionCallback?(false)
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { 
            return 
        }
        
        // Cache the location to avoid repeated API calls
        cachedLocation = location.coordinate
        lastLocationUpdate = Date()
        
        currentLocation = location.coordinate
        locationCallback?(location.coordinate)
        locationCallback = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCallback?(nil)
        locationCallback = nil
    }
}
