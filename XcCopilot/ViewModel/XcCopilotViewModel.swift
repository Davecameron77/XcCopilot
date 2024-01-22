//
//  XcCopilotViewModel.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreLocation
import CoreMotion
import MapKit
import SwiftUI
import os
import WeatherKit

class XcCopilotViewModel: ObservableObject,
                          ViewModelDelegate {
    
    var logger: Logger? = .init(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: XcCopilotViewModel.self)
    )
    
    // Alert vars
    @Published var alertText                                          = ""
    @Published var alertShowing                                       = false
   
    // Motion
    @Published var pitchInDegrees: Double                             = 0.0
    @Published var rollInDegrees: Double                              = 0.0
    @Published var yawInDegrees: Double                               = 0.0
    @Published var accelerationZMetresPerSecondSquared: Double        = 0.0
    
    // GPS
    @Published var gpsCoords: CLLocationCoordinate2D                  = CLLocationCoordinate2D.init(latitude: 0.0, longitude: 0.0)
    @Published var gpsAltitude: CLLocationDistance                    = CLLocationDistance.zero
    @Published var gpsSpeed: CLLocationSpeed                          = CLLocationSpeed.zero
    @Published var gpsCourse: CLLocationDirection                     = CLLocationDirection.zero
    
    // Altimeter
    @Published var baroAltitude: Double                               = 0.0
    @Published var calculatedElevation: Double                        = 0.0
    @Published var verticalVelocityMetresPerSecond: Double            = 0.0
    @Published var glideRangeInMetres: Double                         = 0.0
    
    // Compass
    @Published var magneticHeading: Double = 0.0
    
    // Weather
    @Published var currentWeather: Weather?
    
    // Flight Recorder
    @Published var logbook: [Flight] = [Flight]()
    @Published var flightTime: Duration = .zero
    
    // Map
    @Published var mapPosition: MapCameraPosition
    private var cameraBackup: MapCameraPosition = .camera(MapCamera(centerCoordinate: .myLocation, distance: 500))
    
    // Settings
    /// True in case user has audio selected active
    @AppStorage("audioActive") var audioActive: Bool = true {
       willSet {
          DispatchQueue.main.async {
             self.objectWillChange.send()
          }
       }
    }
    /// The vario volume to use
    @AppStorage("varioVolume") var varioVolume: Double = 100.0 {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    @AppStorage("speedUnit") var speedUnit: SpeedUnits = .kmh {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    @AppStorage("elevationUnit") var elevationUnit: ElevationUnits = .metres {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    @AppStorage("verticalSpeedUnit") var verticalSpeedUnit: VerticalSpeedUnits = .mps {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    @AppStorage("temperatureUnit") var temperatureUnit: TemperatureUnits = .c {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    @AppStorage("gaugeType") var gaugeType: GaugeType = .gauge {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    // Glider metadata
    @AppStorage("gliderName") var gliderName: String = "Unnamed Glider" {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    @AppStorage("trimSpeed") var trimSpeed: Double = 34.0 {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
    }
    
    let REFRESH_FREQUENCY: Double = 0.1
    private var updateTimer: Timer?
    private var currentWeatherTimestamp: Date = Date.distantPast
    var readyToFly: Bool { flightComputer.readyToFly }
    var flightComputer: FlightComputerService
    var flightRecorder: FlightRecorderService
    let weatherService = WeatherService()
    
    ///
    /// Init a new ViewModel with default properties
    ///
    init() {
        flightComputer = FlightComputer()
        flightRecorder = FlightRecorder()
        
        self.mapPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: cameraBackup)
        
        #if DEBUG
        let dummyOne = Flight(isDummy: true)
        dummyOne.flightTitle = "Dummy Flight One"
        logbook.append(dummyOne)
        
        let dummyTwo = Flight(isDummy: true)
        logbook.append(dummyTwo)
        #endif
        
        /// Run loop for the ViewModel, polling the flight computer and updating display vars
        updateTimer = Timer.scheduledTimer(withTimeInterval: REFRESH_FREQUENCY,
                                           repeats: true) { timer in
            self.updateFlightVars()
            self.updateWeather()
            self.logFlightFrame()
        }
    }
    
    ///
    /// Updates VM flight vars for display in the GUI
    ///
    func updateFlightVars() {
        self.pitchInDegrees = self.flightComputer.pitchInDegrees
        self.rollInDegrees = self.flightComputer.rollInDegrees
        self.yawInDegrees = self.flightComputer.yawInDegrees
        self.verticalVelocityMetresPerSecond = self.flightComputer.verticalVelocityMetresPerSecond
        self.glideRangeInMetres = self.flightComputer.glideRangeInMetres
        
        if self.verticalVelocityMetresPerSecond > 0.5 {
            #warning("TODO - Playback frequency")
            if audioActive {
                SoundManager.shared.player?.setVolume(Float(varioVolume), fadeDuration: TimeInterval.leastNonzeroMagnitude)
                SoundManager.shared.playAscendingTone()
            }
        } else if self.verticalVelocityMetresPerSecond < -0.5 {
            #warning("TODO - Playback frequency")
            if audioActive {
                SoundManager.shared.player?.setVolume(Float(varioVolume), fadeDuration: TimeInterval.leastNonzeroMagnitude)
                SoundManager.shared.playDescendingTone()
            }
        }
        
        self.gpsCoords = self.flightComputer.currentCoords
        self.gpsAltitude = self.elevationUnits(elevationMetres: self.flightComputer.gpsAltitude)
        self.gpsSpeed = self.speedUnits(speedMetresSecond: self.flightComputer.gpsSpeed)

        // In case a course is not detected, assigns the current magnetic heading for display
        self.gpsCourse = self.flightComputer.gpsCourse == -1.0 ? self.magneticHeading : self.flightComputer.gpsCourse
        
        self.baroAltitude = self.elevationUnits(elevationMetres: self.flightComputer.baroAltitude)
        self.calculatedElevation = self.elevationUnits(elevationMetres: self.flightComputer.calculatedElevation)
        self.magneticHeading = self.flightComputer.magneticHeading
        
        flightTime = Duration.seconds(self.flightComputer.flightTime)
    }
    
    ///
    /// Requests a weather update if current weather is more than 30 mins old
    ///
    func updateWeather() {
        if Date.now.distance(to: self.currentWeatherTimestamp) > TimeInterval(1800) || self.currentWeather == nil {
            let location = CLLocation(
                latitude: self.flightComputer.currentCoords.latitude,
                longitude: self.flightComputer.currentCoords.longitude
            )
            
            Task {
                if let weather = try? await self.fetchWeather(for: location) {
                    DispatchQueue.main.async {
                        self.currentWeather = weather
                        self.currentWeatherTimestamp = Date.now
                    }
                }
            }
        }
    }
    
    ///
    /// Fetches a weather update
    ///
    func fetchWeather(for location: CLLocation) async throws -> Weather? {
        var weather: Weather?
        try weather = await weatherService.weather(for: location)
        return weather
    }

    ///
    /// Logs a flight frame with the FlightRecorderService
    ///
    func logFlightFrame() {
        // Log flight
        if self.flightComputer.inFlight {
            let frame = FlightFrame(
                pitchInDegrees: self.pitchInDegrees,
                rollInDegrees: self.rollInDegrees,
                yawInDegrees: self.yawInDegrees,
                acceleration: self.flightComputer.acceleration,
                gravity: self.flightComputer.gravity,
                gpsAltitude: self.gpsAltitude,
                gpsCourse: self.gpsCourse,
                gpsCoords: self.gpsCoords,
                baroAltitude: self.baroAltitude,
                verticalVelocity: self.verticalVelocityMetresPerSecond
            )
            
            // Store the frame
            if !self.flightRecorder.recording {
                self.flightRecorder.startRecording()
            }
            self.flightRecorder.storeFrame(frame: frame)
        }
    }
}

/// Helper methods
extension XcCopilotViewModel {
    ///
    /// Shows an alert on screen
    ///
    /// - Parameter withText: The text to show
    func showAlert(withText alertText: String) {
        self.alertText = alertText
        self.alertShowing = true
    }
    
    /// Converts a speed from standard m/s to the configured speed unit
    ///
    /// - Parameter speedMetresSecond: The input speed to convert
    private func speedUnits(speedMetresSecond: Double) -> Double {
        if speedMetresSecond == -1.0 {
            return .nan
        }
        switch self.speedUnit {
        case .kmh:
            return speedMetresSecond * 3.6
        case .mph:
            return speedMetresSecond * 2.23694
        case .knot:
            return speedMetresSecond * 1.9438477170141
        case .mps:
            return speedMetresSecond
        }
    }
    
    /// Converts an elevation from standard metres to the configured elevation unit
    ///
    /// - Parameter elevationMetresd: The input elevation to convert
    private func elevationUnits(elevationMetres: Double) -> Double {
        if elevationMetres == 0.0 {
            return 0.0
        }
        switch self.elevationUnit {
        case .metres:
            return elevationMetres
        case .feet:
            return elevationMetres * 3.28084
        }
    }
    
    /// Converts a temperature from the default unit to the configured temperature unit
    ///
    /// - Parameter temperature: The input temperature to convert
    private func temperatureUnits(temperature: Measurement<UnitTemperature>) -> Measurement<UnitTemperature> {
        switch self.temperatureUnit {
        case .c:
            return temperature
        case .f:
            return temperature.converted(to: .fahrenheit)
        }
    }
}
