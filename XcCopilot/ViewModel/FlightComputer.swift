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
    
    //MARK: -- Vars
    
    var delegate: ViewModelDelegate?

    // State
    var inFlight: Bool = false
    var readyToFly: Bool {
    #if DEBUG
        return true
    #else
        altAvailable && gpsAvailable && motionAvailable
    #endif
    }
    var launchTimeStamp: Date?
    var flightTime: TimeInterval {
        if inFlight && launchTimeStamp != nil {
            Date.now.timeIntervalSince(launchTimeStamp!)
        } else {
            TimeInterval.zero
        }
    }
    // altAvailable means an altitude data has been received
    var altAvailable: Bool = false
    // gpsAvailable means CoreLocation updates have been requested without error
    var gpsAvailable: Bool = false
    // motionAvailable means CoreMotion updates have been received
    var motionAvailable: Bool = false
    
    // GPS
    var gpsAltitude = 0.0
    var gpsSpeed = 0.0
    var gpsCourse = 0.0
    var magneticHeading = 0.0
    var currentCoords: CLLocationCoordinate2D = .init(latitude: 0, longitude: 0)
    
    // Acceleration
    var pitchInDegrees = 0.0
    var rollInDegrees = 0.0
    var yawInDegrees = 0.0
    var acceleration: CMAcceleration = .init(x: 0, y: 0, z: 0)
    var gravity: CMAcceleration = .init(x: 0, y: 0, z: 0)
    
    // Baro/Altitude/Elevation
    var baroAltitude = 0.0
    var terrainElevation = 0.0
    var calculatedElevation = 0.0
    var glideRangeInMetres: Double {
        // Estimate glide ratio 10:1
        return calculatedElevation * glideRatio
    }
    var glideRatio: Double {
        if gpsSpeed < 1.5 {
            return 0.0
        }
        
        let ratio = abs((gpsSpeed / verticalVelocityMetresPerSecond).rounded(toPlaces: 1))
        
        return ratio > 0 ? ratio : Double.infinity
    }
    var verticalVelocityMetresPerSecond = 0.0
    var verticalAccelerationMetresPerSecondSquared = 0.0
    var nearestThermal: CLLocationCoordinate2D?
    var headingToNearestThermal: Double = .nan
    var distanceToNearestThermal: Double = .nan
    var computationCycle = 0.0
    
    // For vertical velocity and elevation calculations
    private var baroAltitudeHistory: [Double] = []
    private var zAccelerationHistory: [Double] = []
    private var verticalVelocityHistory: [Double] = []
    private let MAX_BARO_HISTORY  = 12
    private let MAX_ACCEL_HISTORY  = 100
    private var lastElevationUpdate = Date.distantPast
    private let SECONDS_BETWEEN_ELEVATION_UPDATES = 10
    
    // Services
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motionManager = CMMotionManager()
    private let cmRecorder = CMSensorRecorder()
    private let refreshQueue = OperationQueue()
    private let kalmanFilter = KalmanFilter()
    
    //MARK: -- Methods
    
    ///
    /// Just triggers an inFlight bool to be aware of state. Takeoff detection only functions when !inFlight
    ///
    func startFlying() throws {
        // If we aren't ready for flight, alert user
        guard readyToFly else {
            if !gpsAvailable {
                manager.requestAlwaysAuthorization()
            }
            
            if !altAvailable {
                throw FlightComputerError.altNotAvailable("Baro not available")
            }
            if !gpsAvailable {
                throw FlightComputerError.gpsNotAvailable("GPS not available")
            }
            if !motionAvailable {
                throw FlightComputerError.motionNotAvailable("Motion not available")
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
    /// Also attempts to identify the DMS of any thermals
    ///
    private func calculateVerticalVelocity() {
        
        guard baroAltitudeHistory.count > 2 else { return }
        
        // 1 - Calculate simple moving average of altitude history
        
        // Simple moving average
        var simpleAverage = baroAltitudeHistory.simpleMovingAverage()
        
        #warning("Check this")
        // 2 - Smoothing
        
        // Remove trivial values and append resultant value
        // Vertical velocity is average of past measurements
        
        if verticalVelocityMetresPerSecond > 0 {
            // Ascending
            if simpleAverage < verticalVelocityMetresPerSecond {
                simpleAverage *= 0.75
            }
        } else {
            // Descending
            if simpleAverage > verticalVelocityMetresPerSecond {
                simpleAverage *= 0.75
            }
        }
        verticalVelocityHistory.append(simpleAverage)
        
        verticalVelocityMetresPerSecond = verticalVelocityHistory.effectiveMovingAverage()
        
        // Cleanup
        if verticalVelocityHistory.count > MAX_BARO_HISTORY {
            let recordsToRemove = self.verticalVelocityHistory.count - self.MAX_BARO_HISTORY
            for i in 0 ..< recordsToRemove {
                self.verticalVelocityHistory.remove(at: i)
            }
        }
        
        // 4 - Detect thermic activity by way of consistant acceleration
        
        // If net change is > 0.1g or 0.98 m/s2, interpret a detected thermal
        // CoreMotion collects at 100 hz, with an average trim speed of 30 km/h
        // or 8.3 m/s, yields an average sample of 12.5m travelled at MAX_ACCEL_HISTORY = 100
        verticalAccelerationMetresPerSecondSquared = (zAccelerationHistory.average * 9.81)
                
        if verticalVelocityMetresPerSecond > 0.5 {
            nearestThermal = currentCoords
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

///
/// CoreLocation methods
///
extension FlightComputer {
    ///
    /// Starts CoreLocation Services
    ///
    private func startCoreLocationUpdates() {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            
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
        if !locations.isEmpty {
            // Update telemetry
            currentCoords = locations.first!.coordinate
            gpsAltitude = locations.first!.altitude
            gpsSpeed = locations.first!.speed != -1.0 ? locations.first!.speed : gpsSpeed
            gpsCourse = locations.first!.course
            
            if nearestThermal != nil {
                let latX  = currentCoords.latitude
                let longX = currentCoords.longitude
                let latY  = nearestThermal!.latitude
                let longY = nearestThermal!.longitude
                let deltaLong = longX > longY ? longX - longY : longY - longX
                
                let X = cos(latY) * sin(deltaLong)
                let Y = cos(latX) * sin(latY) - sin(latX) * cos(latY) * cos(deltaLong)
                
                headingToNearestThermal = atan2(X, Y) * 57.3
                
                let currentLocation = CLLocation(latitude: latX, longitude: longX)
                let thermalLocation = CLLocation(latitude: latY, longitude: longY)
                
                distanceToNearestThermal = thermalLocation.distance(from: currentLocation)
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

///
/// CoreMotion methods
///
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
                
                DispatchQueue.global(qos: .userInitiated).async {
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
    private func calculateAbsoluteZAccelration(forGravity gravity: CMAcceleration, forAcceleration acceleration: CMAcceleration) {
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
        if self.zAccelerationHistory.count >= MAX_ACCEL_HISTORY {
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
                    let df = DateFormatter()
                    df.dateFormat = "y-MM-dd H:mm:ss.SSSS"
                    self.baroAltitude = data!.altitude
                    self.baroAltitudeHistory.append(data!.altitude.rounded(toPlaces: 3))
                    
                    // Truncate altitude history to last 12 frames for vertical speed calcs
                    // Barometer samples at 6 hz, with an average trim speed of 30 km/h
                    // or 8.3 m/s, yields an average sample of 16.6m travelled
                    if self.baroAltitudeHistory.count >= self.MAX_BARO_HISTORY {
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

