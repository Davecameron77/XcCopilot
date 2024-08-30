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
        f_k_stateTransitionModel = Matrix(grid: [1.0, t, 0.5 * t * t,
                                                 0.0, 1.0, t,
                                                 0.0, 0.0, 1.0], rows: 3, columns: 3)
        kalmanFilter = KalmanFilter(stateEstimatePrior: x, errorCovariancePrior: errorCovariancePrior)
        
        super.init()
        manager.delegate = self
        startBaroUpdates()
        startCoreLocationUpdates()
        startCoreMotionUpdates()
    }
    
    var delegate: ViewModelDelegate?
    
    // State
    var inFlight: Bool = false
    var readyToFly: Bool {
        #if targetEnvironment(simulator)
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
    var currentCoords = CLLocationCoordinate2D()
    
    // Acceleration
    var pitchInDegrees = 0.0
    var rollInDegrees = 0.0
    var yawInDegrees = 0.0
    var acceleration = CMAcceleration()
    var gravity = CMAcceleration()
    
    // Baro/Altitude/Elevation
    var baroAltitude = 0.0
    var terrainElevation = 0.0
    var calculatedElevation = 0.0
    var glideRangeInMetres = 0.0
    var glideRatio = 10.0
    var verticalSpeedMps = 0.0
    var verticalAccelerationMps2 = 0.0
    var nearestThermal: CLLocationCoordinate2D?
    var headingToNearestThermal: Double = .nan
    var distanceToNearestThermal: Double = .nan
    
    // Wind
    var relativeWindDirection = 0.0
    var relativeWindSpeed = 0.0
    
    // For vertical velocity and elevation calculations
    private var baroAltitudeHistory: [Double] = []
    private var zHistory: [[Double]] = []
    private var verticalSpeedHistory: [Double] = []
    private let MAX_BARO_HISTORY  = 3
    private let MAX_ACCEL_HISTORY  = 400
    private var lastElevationUpdate = Date.distantPast
    private let SECONDS_BETWEEN_ELEVATION_UPDATES = 10
    
    // Kalman filter
    // Initial state vector (Alt, VS, VA)
    private let x = Matrix(vector: [0.0, 0.0, 0.0])
    private let t = 1.0
    // Altitude/VS uncertain, acceleration is not
    private let errorCovariancePrior = Matrix(grid: [10.0, 0.0, 0.0,
                                                     0.0, 10.0, 0.0,
                                                     0.0, 0.0, 1.0], rows: 3, columns: 3)
    // Set at init
    private var f_k_stateTransitionModel: Matrix
    // Fixed to measurements
    private let h_k_observationModel = Matrix(grid: [1.0, 0.0, 0.0,
                                                     0.0, 1.0, 0.0,
                                                     0.0, 0.0, 1.0], rows: 3, columns: 3)
    // Not used
    private let b_k_controlInputModel = Matrix(squareOfSize: 3)
    // Not used
    private let u_k_controlVector = Matrix(vectorOf: 3)
    private var q_k_processNoiseCovariance = Matrix(identityOfSize: 3) * 1e-2
    private var r_k_measurementNoiseCovariance = Matrix(identityOfSize: 3) * 1e-2
    private var kalmanFilter: KalmanFilter<Matrix>
    
    // Services
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motionManager = CMMotionManager()
    private let refreshQueue = OperationQueue()
    
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
            } else if !gpsAvailable {
                throw FlightComputerError.gpsNotAvailable("GPS not available")
            } else if !motionAvailable {
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
    func calculateVerticalVelocity() {
        
        guard !zHistory.isEmpty else {
            verticalSpeedMps = 0.0
            return
        }
        
        // 1 - Base case
        verticalSpeedMps = baroAltitudeHistory.simpleMovingAverage()
        
        // 2 - Kalman Filter
        if let measurement = zHistory.last  {
            
            // Measurement
            let z = Matrix(vector: [measurement[0], measurement[1], measurement[2]])
            
            kalmanFilter = kalmanFilter.predict(
                stateTransitionModel: f_k_stateTransitionModel,
                controlInputModel: b_k_controlInputModel,
                controlVector: u_k_controlVector,
                covarianceOfProcessNoise: q_k_processNoiseCovariance
            )
            
            kalmanFilter = kalmanFilter.update(
                measurement: z,
                observationModel: h_k_observationModel,
                covarienceOfObservationNoise: r_k_measurementNoiseCovariance
            )
        }
        
        let predictedVerticalSpeed = kalmanFilter.stateEstimatePrior[1, 0]
        
        // 3 Apply filter / gain
        verticalSpeedMps = abs(predictedVerticalSpeed) > 0.1 ? predictedVerticalSpeed : 0.0
        
        if baroAltitudeHistory.count > 2 {
            let derrivedVerticalSpeed = baroAltitudeHistory.last! - baroAltitudeHistory.first!
            if derrivedVerticalSpeed > 0.5 {
                verticalSpeedMps *= 1.25
            }
        }
        
        // 4 - Assignment / maintenance
        verticalSpeedHistory.append(verticalSpeedMps)
        
        // Detect thermic activity by way of consistant acceleration
        // If net change is > 0.1g or 0.98 m/s2, or consistent 0.5 m/s vertical velocity interpret a detected thermal
        if verticalSpeedMps > 0.5 && verticalAccelerationMps2 > 0.1 {
            nearestThermal = currentCoords
        }
        
        // Glide Ratio
        if gpsSpeed > 1.5 && verticalSpeedMps < 0.0 {
            let ratio = (gpsSpeed / abs(verticalSpeedMps)).rounded(toPlaces: 1)
            glideRatio = ratio > 0 ? ratio : 10
        } else {
            glideRatio = .zero
        }
        
        // Cleanup
        if verticalSpeedHistory.count > MAX_BARO_HISTORY {
            let recordsToRemove = self.verticalSpeedHistory.count - self.MAX_BARO_HISTORY
            for i in 0 ..< recordsToRemove {
                self.verticalSpeedHistory.remove(at: i)
            }
        }
    }
    
    ///
    /// Calculates the current elevation based on lat/long and altitude
    /// Periodically updates elevation reference to calculate against
    ///
    func calculateElevation() async {
        
        // Update elevation reference
        if Date.now - self.lastElevationUpdate > TimeInterval(self.SECONDS_BETWEEN_ELEVATION_UPDATES) &&
           currentCoords.latitude != 0 &&
            currentCoords.longitude != 0 {
            
            let api = "https://api.open-elevation.com"
            let endpoint = "/api/v1/lookup?locations=\(currentCoords.latitude),\(currentCoords.longitude)"
            guard let url = URL(string: api + endpoint) else { return }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let decodedResponse = try? JSONDecoder().decode(Response.self, from: data) {
                    if decodedResponse.results.first?.elevation != nil {
                        terrainElevation = decodedResponse.results.first!.elevation
                    }
                }
            } catch {
                if delegate != nil && delegate?.logger != nil {
                    delegate!.logger!.error("CoreMotion: Error retrieiving location")
                    delegate!.logger!.error("Error: \(error.localizedDescription)")
                } else if delegate != nil {
                    delegate!.logger!.error("Error fetching elevation data")
                }
            }
        }
        
        // Calculate elevation based on last known reference
        calculatedElevation = Double.maximum(baroAltitude - terrainElevation, 0)
        glideRangeInMetres = calculatedElevation * glideRatio
        
        // Detect a landing, no velocity and no elevation
        if inFlight && terrainElevation < 3 && self.gpsSpeed < 1 {
            stopFlying()
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
            
            // Update direction to nearest thermal
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
            
            // Estimate relative wind
            calculateRelativeWind()
        }
    }
    
    ///
    /// Handles a received heading update
    ///
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        magneticHeading = newHeading.magneticHeading
    }
    
    ///
    ///j   /// Handles a failure in location authorication
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
    /// - Returns true if GPS avail
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
        motionManager.startDeviceMotionUpdates(to: refreshQueue) { data, error in
            if data != nil {
                self.motionAvailable = true
                
                // Convert from radians to degrees
                self.pitchInDegrees = data!.attitude.pitch * 57.2958
                self.rollInDegrees = data!.attitude.roll * 57.2958
                self.yawInDegrees = data!.attitude.yaw * 57.2958
                
                self.acceleration = data!.userAcceleration
                self.gravity = data!.gravity
                
            } else {
                self.motionAvailable = false
            }
        }
    }
    
    ///
    /// Calculates Z acceleration
    ///
    /// - Parameter forGravity: Measured gravity to measure against
    /// - Parameter forAcceleration: Measured acceleration to measure against
    ///
    /// - Returns Derrived acceleration in Z, double
    private func calculateAbsoluteZAcceleration(forGravity gravity: CMAcceleration, forAcceleration acceleration: CMAcceleration) -> Double {
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
        return zVector.length()
    }
    
    ///
    /// Estimates wind speed and direction based on GPS  and compass measurements
    /// Calculated measurement will only be between 0 - 10 m/s
    ///
    private func calculateRelativeWind() {
        let groundTrack = gpsCourse.degreesToRadians
        let airTrack = magneticHeading.degreesToRadians
        let trimSpeed = delegate?.trimSpeed ?? 34.0
        
        // Calculate the components of the groundspeed vectors
        let groundSpeedX = gpsSpeed * cos(groundTrack)
        let groundSpeedY = gpsSpeed * sin(groundTrack)
        let trimSpeedX = trimSpeed * cos(airTrack)
        let trimSpeedY = trimSpeed * sin(airTrack)
        
        // Calculate wind components
        let windX = groundSpeedX - trimSpeedX
        let windY = groundSpeedY - trimSpeedY
        
        // Calculate wind speed
        relativeWindSpeed = abs(sqrt(windX * windX + windY * windY))
        relativeWindSpeed = relativeWindSpeed.rounded(toPlaces: 1)
        if relativeWindSpeed < 0.0 || relativeWindSpeed > 10.0 {
            relativeWindSpeed = 0.0
        }
        
        // Calculate wind direction
        relativeWindDirection = (atan2(windY, windX) * 180.0 / .pi)
        relativeWindDirection = relativeWindDirection.rounded(toPlaces: 1)
    }
    
    ///
    /// Starts Baro Services
    ///
    private func startBaroUpdates() {
        
        altimeter.startAbsoluteAltitudeUpdates(to: refreshQueue) { data, error in
            
            if data != nil {
                
                self.altAvailable = true
                self.baroAltitude = data!.altitude
                self.baroAltitudeHistory.append(data!.altitude.rounded(toPlaces: 3))
                
                // Cleanup
                if self.baroAltitudeHistory.count >= self.MAX_BARO_HISTORY {
                    let recordsToRemove = self.baroAltitudeHistory.count - self.MAX_BARO_HISTORY
                    for i in 0 ..< recordsToRemove {
                        self.baroAltitudeHistory.remove(at: i)
                    }
                }
                
                if self.zHistory.count > self.MAX_BARO_HISTORY {
                    let recordsToRemove = self.zHistory.count - self.MAX_BARO_HISTORY
                    for i in 0 ..< recordsToRemove {
                        self.zHistory.remove(at: i)
                    }
                }
                
                Task(priority: .high) {
                    // Params for Kalman filter
                    let zAccel = self.calculateAbsoluteZAcceleration(
                        forGravity: self.gravity,
                        forAcceleration: self.acceleration
                    )
                    let altitude = self.baroAltitude.isNaN ? 0.0 : self.baroAltitude
                    let verticalVelocity = self.baroAltitudeHistory.simpleMovingAverage()
                    self.verticalAccelerationMps2 = zAccel.isNaN ? 0.0 : zAccel
                    
                    self.zHistory.append([altitude, verticalVelocity, zAccel])
                    
                    // Calculate vertical speed on every baro update, 6 hz
                    self.calculateVerticalVelocity()
                    // Update elevation if last update is long enough ago
                    await self.calculateElevation()
                }
                
            } else {
                self.altAvailable = false
            }
        }
    }
    
    ///
    /// Checks altimter availability
    ///
    /// - Returns true if barometer is available
    private func checkAltimeterAvailable() -> Bool {
        return altAvailable
    }
    
    ///
    /// Checks CoreMotion availability
    ///
    /// - Returns true if barometer is available
    private func checkMotionAvailable() -> Bool {
        return motionManager.isDeviceMotionAvailable
    }
}

