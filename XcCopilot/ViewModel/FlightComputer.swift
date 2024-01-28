//
//  FlightComputer.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreLocation
import CoreMotion
import SwiftUI

///
/// The FlightComputer is responsible for tracking flight parameters, but has no GUI functions.
/// The ViewModel will poll the FlightComputer for available data to display
///
class FlightComputer: NSObject,
                      CLLocationManagerDelegate,
                      FlightComputerService {

    ///
    /// Init a FlightComputer and try to start all available services
    ///
    override init() {
        super.init()
        manager.delegate = self
        startBaroUpdates()
        startCoreLocationUpdates()
        startCoreMotionUpdates()
    }
    
    convenience init(delegate: ViewModelDelegate) {
        self.init()
        self.delegate = delegate
    }
    
    var delegate: ViewModelDelegate?

    // State
    var inFlight: Bool = false
    var readyToFly: Bool {
        altAvailable && gpsAvailable && motionAvailable
    }
    var launchTimeStamp: Date?
    var flightTime: TimeInterval {
        if inFlight && launchTimeStamp != nil {
            Date.now.timeIntervalSince(launchTimeStamp!)
        } else {
            TimeInterval.leastNonzeroMagnitude
        }
    }
    // altAvailable means an altitude data has been received
    private var altAvailable: Bool = false
    // gpsAvailable means CoreLocation updates have been requested without error
    private var gpsAvailable: Bool = false
    // motionAvailable means CoreMotion updates have been received
    private var motionAvailable: Bool = false
    
    // GPS
    var gpsAltitude                                = 0.0
    var gpsSpeed                                   = 0.0
    var gpsCourse                                  = 0.0
    var magneticHeading                            = 0.0
    var currentCoords: CLLocationCoordinate2D      = .init(latitude: 0, longitude: 0)
    
    // Acceleration
    var pitchInDegrees                             = 0.0
    var rollInDegrees                              = 0.0
    var yawInDegrees                               = 0.0
    var acceleration: CMAcceleration               = .init(x: 0, y: 0, z: 0)
    var gravity: CMAcceleration                    = .init(x: 0, y: 0, z: 0)
    
    // Baro/Altitude/Elevation
    var baroAltitude                               = 0.0
    var terrainElevation                           = 0.0
    var calculatedElevation                        = 0.0
    var glideRangeInMetres: Double {
        return calculatedElevation * 10
    }
    var verticalVelocityMetresPerSecond            = 0.0
    
    // For vertical velocity and elevation calculations
    private var baroAltitudeHistory: [Double]      = .init()
    private var zAccelerationHistory: [Double]     = .init()
    private let MAX_BARO_HISTORY                   = 15
    private let MAX_ACCEL_HISTORY                  = 300
    private var lastElevationUpdate                = Date.distantPast
    private let SECONDS_BETWEEN_ELEVATION_UPDATES  = 10
    
    // Services
    private var manager: CLLocationManager         = .init()
    private var altimeter: CMAltimeter             = .init()
    private var motionManager: CMMotionManager     = .init()
    private var cmRecorder: CMSensorRecorder       = .init()
    private var refreshQueue: OperationQueue       = .init()
    
    ///
    /// Just triggers an inFlight bool to be aware of state. Takeoff detection only functions when !inFlight
    ///
    func startFlying() {
        // If we aren't ready for flight, alert user
        guard readyToFly else {
            if delegate != nil && delegate?.logger != nil {
                delegate?.showAlert(withText: "Sensor error, not ready for flight")
                delegate?.logger?.debug("\(Date.now): Failed to start a flight")
            }
            
            if !gpsAvailable {
                manager.requestAlwaysAuthorization()
            }
            return
        }
        
        inFlight = true
        launchTimeStamp = Date.now
        
        if delegate != nil {
            delegate?.logger?.debug("\(Date.now): Started a flight")
        }
    }
    
    ///
    /// Triggers !inFlight
    ///
    func stopFlying() {
        inFlight = false
        launchTimeStamp = nil
        
        if delegate != nil {
            delegate?.logger?.debug("\(Date.now): Ended a flight")
        }
    }
    
    ///
    /// Calculates VerticalVelocity based on given accelerometer/baro history
    ///
    private func calculateVerticalVelocity() {
        
        // Absolute value of average vertical acceleration
        let averageVerticalAcceleration = abs(zAccelerationHistory.average)
        
        // If net change is < 0.1g or 0.98 m/s2 continue calculation
        // else smooth to zero
        // CoreMotion collects at 100 hz, with an average trim speed of 30 km/h
        // or 8.3 m/s, yields an average sample of 25m travelled at MAX_ACCEL_HISTORY = 300
        #warning("DEBUG value")
        if averageVerticalAcceleration > 0.00001 {
            
            // Sum the differences of the baro altitude history
            var difference = 0.0
            for index in 0 ..< baroAltitudeHistory.count - 1 {
                difference = (baroAltitudeHistory[index+1] - baroAltitudeHistory[index])
            }
            
            // Net change in vertical displacement / number of samples collected
            // Barometer samples at 6 hz, with an average trim speed of 30 km/h
            // or 8.3 m/s, yields an average sample of 21m travelled at MAX_BARO_HISTORY = 15
            verticalVelocityMetresPerSecond = (difference / Double(baroAltitudeHistory.count))
        } else {
            // Insignifigant change, set to zero
            verticalVelocityMetresPerSecond = 0.0
        }
    }
    
    ///
    /// Calculates the current elevation based on lat/long and altitude
    ///
    private func calculateElevation() async {
        if currentCoords.latitude == 0  || currentCoords.longitude == 0 {
            return
        }
        
        struct Response: Codable {
            var results: [Result]
        }
        
        struct Result: Codable {
            var latitude: Double
            var longitude: Double
            var elevation: Double
        }
        
        let api = "https://api.open-elevation.com"
        let endpoint = "/api/v1/lookup?locations=\(currentCoords.latitude),\(currentCoords.longitude)"
        guard let url = URL(string: api + endpoint) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let decodedResponse = try? JSONDecoder().decode(Response.self, from: data) {
                if let terrainElevation = decodedResponse.results.first?.elevation {
                    // Set elevation over ground based on baro reading
                    calculatedElevation = Double.maximum(baroAltitude - terrainElevation, 0)
                }
            }
            
            // Detect a landing, no velocity and no elevation
            if terrainElevation < 3 && self.gpsSpeed < 1 {
            #if DEBUG
                // Don't check for landing when in debug
            #else
                stopFlying()
            #endif
            }
            
        } catch {
            if delegate != nil && delegate?.logger != nil {
                delegate!.logger!.error("CoreMotion: Error retrieiving location")
                delegate!.logger!.error("Error: \(error.localizedDescription)")
            }
        }
    }
}

// CoreLocation methods
extension FlightComputer {
    ///
    /// Starts CoreLocation Services
    ///
    private func startCoreLocationUpdates() {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.startUpdatingLocation()

            self.gpsAvailable = true
        } else {
            self.gpsAvailable = false
        }
    }
    
    ///
    /// Handles a received location update
    ///
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        processLocationUpdate(locations: locations)
    }
    
    ///
    /// Processes a received location update
    ///
    func processLocationUpdate(locations: [CLLocation]) {
        if !locations.isEmpty {
            // Update telemetry
            currentCoords = locations.first!.coordinate
            gpsAltitude = locations.first!.altitude
            gpsSpeed = locations.first!.speed != -1.0 ? locations.first!.speed : gpsSpeed
            gpsCourse = locations.first!.course
            
            // Detect a launch
            if !inFlight && gpsSpeed > 5.5 {
                startFlying()
            }
        }
    }

    ///
    /// Handles a received heading update
    ///
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        magneticHeading = newHeading.magneticHeading
    }

    ///
    /// Handles a failure in location authorication
    ///
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if delegate != nil && delegate?.logger != nil {
            delegate?.logger!.error("\(Date.now): CoreLocation Error: \(error.localizedDescription)")
        }
        
        manager.requestAlwaysAuthorization()
    }

    ///
    /// Handles a change in authorization status
    ///
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {

        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .restricted:
            manager.requestAlwaysAuthorization()
        case .denied:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        case .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        @unknown default:
            if delegate != nil && delegate?.logger != nil {
                delegate?.logger!.error("CoreLocation Error: Unknown location permissions error")
                delegate?.showAlert(withText: "Location permissions error")
            }
        }
    }
    
    ///
    /// Checks for GPS availability
    ///
    private func checkGpsAvailable() -> Bool {
        return manager.authorizationStatus == .authorizedAlways ||
               manager.authorizationStatus == .authorizedWhenInUse
    }
}

// CoreMotion methods
extension FlightComputer {
    ///
    /// Starts CoreMotion Services
    ///
    private func startCoreMotionUpdates() {
        motionManager.startDeviceMotionUpdates(to: refreshQueue) {
            data,
            error in
            if data != nil {
                self.motionAvailable = true
                DispatchQueue.main.async {
                    // Convert from radians to degrees
                    self.pitchInDegrees = data!.attitude.pitch * 57.2958
                    self.rollInDegrees = data!.attitude.roll * 57.2958
                    self.yawInDegrees = data!.attitude.yaw * 57.2958
                    
                    self.acceleration = data!.userAcceleration
                    self.gravity = data!.gravity
                    
                    self.calculateAbsoluteZAccelration(
                        forGravity: data!.gravity,
                        forAcceleration: data!.userAcceleration
                    )
                }
            } else {
                self.motionAvailable = false
            }
        }
    }
    
    ///
    /// Calculates Z acceleration
    ///
    private func calculateAbsoluteZAccelration(
        forGravity gravity: CMAcceleration,
        forAcceleration acceleration: CMAcceleration
    ) {
        // Gravity for orientation
        let gravityVector = Vector3(
            x: CGFloat(gravity.x),
            y: CGFloat(gravity.y),
            z: CGFloat(gravity.z)
        )
        
        // Current motion vector
        let accelerationVector = Vector3(
            x: CGFloat(acceleration.x),
            y: CGFloat(acceleration.y),
            z: CGFloat(acceleration.z)
        )
        
        // Combined net acceleration
        let zVector = gravityVector * accelerationVector
        // Z Axis only
        let zAcceleration = zVector.length()
        
        zAccelerationHistory.append(zAcceleration)
        
        // Constrain array to avoid overflow
        if self.zAccelerationHistory.count > MAX_ACCEL_HISTORY {
            let recordsToRemove = zAccelerationHistory.count - MAX_ACCEL_HISTORY
            for i in 0 ..< recordsToRemove {
                zAccelerationHistory.remove(at: i)
            }
        }
    }
    
    ///
    /// Starts Baro Services
    ///
    private func startBaroUpdates() {
        
        altimeter.startAbsoluteAltitudeUpdates(to: refreshQueue) { data, error in

            if data != nil {
                self.altAvailable = true
                DispatchQueue.main.async {
                    self.baroAltitude = data!.altitude
                    self.baroAltitudeHistory.append(data!.altitude)
                    
                    // Truncate altitude history to last 15 frames for vertical speed calcs
                    // Barometer samples at 6 hz, with an average trim speed of 30 km/h
                    // or 8.3 m/s, yields an average sample of 21m travelled
                    if self.baroAltitudeHistory.count > self.MAX_BARO_HISTORY {
                        let recordsToRemove = self.baroAltitudeHistory.count - self.MAX_BARO_HISTORY
                        for i in 0 ..< recordsToRemove {
                            self.baroAltitudeHistory.remove(at: i)
                        }
                    }
                    
                    // Calculate vertical speed on every baro update, 6 hz
                    self.calculateVerticalVelocity()
                    
                    // Update elevation if last update is long enough ago
                    if Date.now - self.lastElevationUpdate > TimeInterval(self.SECONDS_BETWEEN_ELEVATION_UPDATES) {
                        Task { await self.calculateElevation() }
                    }
                    
                }
            } else {
                self.altAvailable = false
            }
        }
    }
    
    ///
    /// Checks altimter availability
    ///
    private func checkAltimeterAvailable() -> Bool {
        return altAvailable
    }
    
    ///
    /// Checks CoreMotion availability
    ///
    private func checkMotionAvailable() -> Bool {
        return motionManager.isDeviceMotionAvailable
    }
}
