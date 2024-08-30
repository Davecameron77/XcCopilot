//
//  ReplayComputer.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-08-18.
//

import Foundation
import CoreLocation
import CoreMotion
import SwiftUI

///
/// The replay computer is for tuning the kalman filter. A recorded flight can be played back through a flight computer
/// enabling parameters to be tuned for the best perfomrance.
///
class ReplayComputer: NSObject,
                      CLLocationManagerDelegate,
                      FlightComputerService {
    
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
    // Static values
    private var q_k_processNoiseCovariance = Matrix(identityOfSize: 3) * 1e-2
    private var r_k_measurementNoiseCovariance = Matrix(identityOfSize: 3) * 1e-2
    private var kalmanFilter: KalmanFilter<Matrix>
    
    ///
    /// Init a FlightComputer and try to start all available services
    ///
    override init() {
        f_k_stateTransitionModel = Matrix(grid: [1.0, t, 0.5 * t * t,
                                                 0.0, 1.0, t,
                                                 0.0, 0.0, 1.0], rows: 3, columns: 3)
        kalmanFilter = KalmanFilter(stateEstimatePrior: x, errorCovariancePrior: errorCovariancePrior)
        
        super.init()
        
        let records = getJSONData()
        var count = 0
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: REFRESH_FREQUENCY,
                                           repeats: true) { timer in
//            print("Sequence: \(self.timeDelay)")
            
            self.timeDelay += 1
            if self.timeDelay >= 0 && Int(self.timeDelay) < records.count{
                // GPS
                let latDeg = records[Int(self.timeDelay)].Latitude!
                let lngDeg = records[Int(self.timeDelay)].Longitude!
                self.currentCoords = CLLocationCoordinate2D(latitude: latDeg, longitude: lngDeg)
                self.gpsSpeed = records[Int(self.timeDelay)].Speed!
                self.gpsAltitude = records[Int(self.timeDelay)].GPSAlt!
                self.magneticHeading = records[Int(self.timeDelay)].Heading!
                self.gpsCourse = records[Int(self.timeDelay)].Course!
                
                self.baroAltitude = records[Int(self.timeDelay)].BaroAlt!
                self.baroAltitudeHistory.append(self.baroAltitude)
                if Int(self.timeDelay) < records.count - 2 {
                    let diffToNext = records[Int(self.timeDelay) + 1].BaroAlt! - records[Int(self.timeDelay)].BaroAlt!
                    let plusOne = self.baroAltitude + diffToNext * 0.33
                    let plusTwo = self.baroAltitude + diffToNext * 0.66
                    self.baroAltitudeHistory.append(plusOne)
                    self.baroAltitudeHistory.append(plusTwo)
                }
                self.gpsAltitude = records[Int(self.timeDelay)].GPSAlt!
                
                self.pitchInDegrees = records[Int(self.timeDelay)].GyroY! * 57.2958
                self.rollInDegrees = records[Int(self.timeDelay)].GyroX! * 57.2958
                self.yawInDegrees = records[Int(self.timeDelay)].GyroZ! * 57.2958
                
                let accelX = records[Int(self.timeDelay)].AcclX!
                let accelY = records[Int(self.timeDelay)].AcclY!
                let accelZ = records[Int(self.timeDelay)].AcclZ!
                self.acceleration = CMAcceleration(x: accelX, y: accelY, z: accelZ)
                
                self.calculateVerticalVelocity()
             
                // Update direction to nearest thermal
                if self.nearestThermal != nil {
                    let latX  = self.currentCoords.latitude
                    let longX = self.currentCoords.longitude
                    let latY  = self.nearestThermal!.latitude
                    let longY = self.nearestThermal!.longitude
                    let deltaLong = longX > longY ? longX - longY : longY - longX

                    let X = cos(latY) * sin(deltaLong)
                    let Y = cos(latX) * sin(latY) - sin(latX) * cos(latY) * cos(deltaLong)

                    self.headingToNearestThermal = atan2(X, Y) * 57.3

                    let currentLocation = CLLocation(latitude: latX, longitude: longX)
                    let thermalLocation = CLLocation(latitude: latY, longitude: longY)

                    self.distanceToNearestThermal = thermalLocation.distance(from: currentLocation)
                }
                
                // Estimate relative wind
                self.calculateRelativeWind()
                
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
                    let zAccel = records[Int(self.timeDelay)].AcclZ! / 10 * -1
                    let altitude = self.baroAltitude.isNaN ? 0.0 : self.baroAltitude
                    let verticalVelocity = self.verticalSpeedMps.isNaN ? 0.0 : self.verticalSpeedMps

                    self.verticalAccelerationMps2 = zAccel.isNaN ? 0.0 : zAccel
                    self.zHistory.append([altitude, verticalVelocity, zAccel])

                    // Update elevation if last update is long enough ago
                    await self.calculateElevation()
                }
            }
        }
        
        manager.delegate = self
    }
    
    var delegate: ViewModelDelegate?
    private let REFRESH_FREQUENCY = 0.05
    private var timeDelay = -5.0
    private var updateTimer: Timer?
    
    // State
    var inFlight: Bool = false
    var readyToFly = true
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
    var currentCoords = CLLocationCoordinate2D(latitude: 49.2283029, longitude: -121.9019453)
    
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
    private let MAX_BARO_HISTORY  = 6
    private let MAX_ACCEL_HISTORY  = 400
    private var lastElevationUpdate = Date.distantPast
    private let SECONDS_BETWEEN_ELEVATION_UPDATES = 10
    
    // Services
    private let manager = CLLocationManager()
    private let altimeter = CMAltimeter()
    private let motionManager = CMMotionManager()
    private let refreshQueue = OperationQueue()
    
    ///
    /// Just triggers an inFlight bool to be aware of state. Takeoff detection only functions when !inFlight
    ///
    func startFlying() throws {
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
}

///
/// CoreMotion methods
///
extension ReplayComputer {
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
        verticalSpeedMps = baroAltitudeHistory.effectiveMovingAverage()
        
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
        
        let sma = baroAltitudeHistory.simpleMovingAverage()
        print("\(baroAltitude), \(sma.rounded(toPlaces: 1)), \(verticalSpeedMps.rounded(toPlaces: 1)), \(predictedVerticalSpeed.rounded(toPlaces: 1))")
        
        // 4 - Assignment / maintenance
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
        
        if currentCoords.latitude == 0  || currentCoords.longitude == 0 {
            return
        }
        
        // Update elevation reference
        if Date.now - self.lastElevationUpdate > TimeInterval(self.SECONDS_BETWEEN_ELEVATION_UPDATES) {
            
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
                self.lastElevationUpdate = Date.now
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
    
    ///
    /// Estimates wind speed and direction based on GPS  and compass measurements
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
        relativeWindSpeed = sqrt(windX * windX + windY * windY)
        relativeWindSpeed = abs(relativeWindSpeed.rounded(toPlaces: 1))
        
        // Calculate wind direction
        relativeWindDirection = (atan2(windY, windX) * 180.0 / .pi)
        relativeWindDirection = relativeWindDirection.rounded(toPlaces: 1)
    }
    
    func getJSONData() -> [Record] {
        let decoder = JSONDecoder()
        
        if let urlPath = Bundle.main.url(forResource: "sample_flight", withExtension: "json") {
            if let data = try? Data(contentsOf: urlPath) {
                do {
                    return try decoder.decode([Record].self, from: data)
                } catch {
                    print("Exception: \(error)")
                }
            }
        }
        return []
    }
    
    struct Record: Codable {
        var Milliseconds : Int?    = nil
        var Seconds      : Int?    = nil
        var Latitude     : Double? = nil
        var LatDegree    : Int?    = nil
        var LatMinute    : Int?    = nil
        var LatSecond    : Double? = nil
        var Longitude    : Double? = nil
        var LongDegree   : Int?    = nil
        var LongMinute   : Int?    = nil
        var LongSecond   : Double? = nil
        var BaroAlt      : Double? = nil
        var GPSAlt       : Double? = nil
        var Speed        : Double? = nil
        var AcclX        : Double? = nil
        var AcclY        : Double? = nil
        var AcclZ        : Double? = nil
        var GyroX        : Double? = nil
        var GyroY        : Double? = nil
        var GyroZ        : Double? = nil
        var Course       : Double? = nil
        var Heading      : Double? = nil
        
        enum CodingKeys: String, CodingKey {
            
            case Milliseconds = "Milliseconds"
            case Seconds      = "Seconds"
            case Latitude     = "Latitude"
            case LatDegree    = "Lat_Degree"
            case LatMinute    = "Lat_Minute"
            case LatSecond    = "Lat_Second"
            case Longitude    = "Longitude"
            case LongDegree   = "Long_Degree"
            case LongMinute   = "Long_Minute"
            case LongSecond   = "Long_Second"
            case BaroAlt      = "Baro_Alt"
            case GPSAlt       = "GPS_Alt"
            case Speed        = "Speed"
            case AcclX        = "AcclX"
            case AcclY        = "AcclY"
            case AcclZ        = "AcclZ"
            case GyroX        = "GyroX"
            case GyroY        = "GyroY"
            case GyroZ        = "GyroZ"
            case Course       = "Course"
            case Heading      = "Heading"
        }
    }
}

