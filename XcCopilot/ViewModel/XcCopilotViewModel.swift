//
//  XcCopilotViewModel.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreData
import CoreLocation
import CoreMotion
import MapKit
import SwiftUI
import os
import WeatherKit
import UniformTypeIdentifiers
import SwiftData

class XcCopilotViewModel: ObservableObject, ViewModelDelegate {
    var logger: Logger? = .init(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: XcCopilotViewModel.self)
    )
    
    var flightState: FlightState = .landed
    
    // Alert vars
    @Published var alertText = ""
    @Published var alertShowing = false
   
    // Motion
    @Published var verticalAccelerationMetresPerSecondSquared = 0.0
    
    // GPS
    @Published var gpsCoords = CLLocationCoordinate2D.init(latitude: 0.0, longitude: 0.0)
    @Published var gpsAltitude = CLLocationDistance.zero
    @Published var gpsSpeed = CLLocationSpeed.zero
    @Published var gpsCourse = CLLocationDirection.zero
    
    // Altimeter
    @Published var baroAltitude = 0.0
    @Published var calculatedElevation = 0.0
    @Published var verticalVelocityMetresPerSecond = 0.0
    @Published var glideRangeInMetres = 0.0
    @Published var nearestThermalHeading = 0.0
    @Published var nearestThermalDistance = 0.0
    @Published var glideRatio = 1.0
    
    // Permissions
    @Published var altAvailable = false
    @Published var gpsAvailable = false
    @Published var motionAvailable = false
    
    // Compass
    @Published var magneticHeading = 0.0
    
    // Weather
    @Published var currentWeather: Weather?
    
    // Flight Recorder
    @Published var flightTime: Duration = .zero
    
    // Map
    @Published var mapPosition: MapCameraPosition
    private var cameraBackup: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: .myLocation,
            distance: 500
        )
    )
    
    // Settings
    /// True in case user has audio selected active
    @AppStorage("audioActive") var audioActive = true {
       willSet {
          DispatchQueue.main.async {
             self.objectWillChange.send()
          }
       }
    }
    /// The vario volume to use
    @AppStorage("varioVolume") var varioVolume = 100.0 {
        willSet {
           DispatchQueue.main.async {
              self.objectWillChange.send()
           }
        }
        didSet {
            SoundManager.shared.player?.setVolume(Float(varioVolume), fadeDuration:  TimeInterval.leastNonzeroMagnitude)
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
    
    let REFRESH_FREQUENCY = 1.0
    private var updateTimer: Timer?
    
    private var currentWeatherTimestamp = Date.distantPast
    var readyToFly: Bool { flightComputer.readyToFly }
    var flightComputer: FlightComputerService
    var flightRecorder: FlightRecorder
    let weatherService = WeatherService()
    
    ///
    /// Init a new ViewModel with default properties
    ///
    init() {
        mapPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: cameraBackup)
        
        flightComputer = FlightComputer()
        flightRecorder = FlightRecorder()
        
        flightComputer.delegate = self
        
        // Run loop for the ViewModel, polling the flight computer and updating display vars
        updateTimer = Timer.scheduledTimer(withTimeInterval: REFRESH_FREQUENCY,
                                           repeats: true) { timer in
            self.updateFlightVars()
            self.updateWeather()
            self.logFlightFrame()
        }
    }
    
    ///
    /// Arms to be ready for flight
    ///
    func armForFlight() {
        flightState = .armed
        Task {
            await flightRecorder.armForFlight()
        }
    }
    
    ///
    /// Starts a Flight
    ///
    func startFlying() {
        flightState = .inFlight
        do {
            try flightComputer.startFlying()
        } catch  {
            logger?.debug("\(error.localizedDescription)")
        }
    }
    
    ///
    /// Ends a Flight
    ///
    func stopFlying() {
        flightState = .landed
        flightComputer.stopFlying()
        Task {
            do {
                try await flightRecorder.endFlight(withWeather: currentWeather)
            } catch {
                showAlert(withText: error.localizedDescription)
                logger?.debug("\(error.localizedDescription)")
            }
        }
    }
    
    ///
    /// Updates VM flight vars for display in the GUI
    ///
    func updateFlightVars() {
        verticalVelocityMetresPerSecond = flightComputer.verticalVelocityMetresPerSecond
        verticalAccelerationMetresPerSecondSquared = flightComputer.verticalAccelerationMetresPerSecondSquared
        glideRangeInMetres = flightComputer.glideRangeInMetres
        glideRatio = flightComputer.glideRatio
        
        gpsCoords = flightComputer.currentCoords
        gpsAltitude = elevationUnits(elevationMetres: flightComputer.gpsAltitude)
        gpsSpeed = speedUnits(speedMetresSecond: flightComputer.gpsSpeed)

        // In case a course is not detected, assigns the current magnetic heading for display
        gpsCourse = flightComputer.gpsCourse == -1.0 ? magneticHeading : flightComputer.gpsCourse
        
        baroAltitude = elevationUnits(elevationMetres: flightComputer.baroAltitude)
        calculatedElevation = elevationUnits(elevationMetres: flightComputer.calculatedElevation)
        magneticHeading = flightComputer.magneticHeading
        
        // Detect a launch
        if flightState == .armed && gpsSpeed > 5.5 {
            startFlying()
        }
        
        // Flight specific tracking
        if flightState == .inFlight {
            nearestThermalHeading = flightComputer.headingToNearestThermal
            nearestThermalDistance = flightComputer.distanceToNearestThermal
            
            flightTime = Duration.seconds(flightComputer.flightTime)
            
            playVarioSound()
        }
    }
    
    ///
    /// Plays tones based on current vertical velocity
    ///
    func playVarioSound() {
        if !audioActive { return }
        
        switch verticalVelocityMetresPerSecond {
        case -100 ..< -4.0:
            // Play at 6hz
            SoundManager.shared.playTone(forFrequency: .sixHzDescend)
        case -4.0 ..< -1.0:
            // Play at 4hz
            SoundManager.shared.playTone(forFrequency: .fourHzDescend)
        case -1.0 ..< -0.25:
            // Play at 2hz
            SoundManager.shared.playTone(forFrequency: .twoHzDescend)
        case -0.25 ..< 0.25:
            // Trivial vertical motion
            return
        case 0.25 ..< 2.0:
            // Play at 2hz
            SoundManager.shared.playTone(forFrequency: .twoHzAscend)
        case 2.0 ..< 4.0:
            // Play at 4hz
            SoundManager.shared.playTone(forFrequency: .fourHzAscend)
        case 4.0 ..< 100:
            // Play at 4hz
            SoundManager.shared.playTone(forFrequency: .sixHzAscend)
        default:
            return
        }
    }
    
    ///
    /// Requests a weather update if current weather is more than 30 mins old
    ///
    func updateWeather() {
        if Date.now.distance(to: self.currentWeatherTimestamp) > TimeInterval(1800) || self.currentWeather == nil {
            let location = CLLocation(
                latitude: flightComputer.currentCoords.latitude,
                longitude: flightComputer.currentCoords.longitude
            )
            
            Task {
                if let weather = try? await self.fetchWeather(forLocation: location) {
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
    /// - Parameter forLocation - The location to fetch weather for
    func fetchWeather(forLocation location: CLLocation) async throws -> Weather? {
        var weather: Weather?
        try weather = await weatherService.weather(for: location)
        return weather
    }

    ///
    /// Logs a flight frame with the FlightRecorderService
    ///
    func logFlightFrame() {
        // Log flight
        if flightComputer.inFlight {
            Task {
                do {
                    try await flightRecorder.storeFrame(
                        acceleration: flightComputer.acceleration,
                        gravity: flightComputer.gravity,
                        gpsAltitude: gpsAltitude,
                        gpsCourse: gpsCourse,
                        gpsCoords: gpsCoords,
                        baroAltitude: baroAltitude,
                        verticalVelocity: verticalVelocityMetresPerSecond
                    )
                } catch {
                    logger?.debug("\(error.localizedDescription)")
                }
            }
        }
    }
    
    ///
    /// Imports an IGC file
    ///
    /// - Parameter forUrl: The file to import
    func importIgcFile(forUrl url: URL) async -> Bool {
        await Task {
            do {
                try await flightRecorder.importFlight(forUrl: url)
                return true
            } catch {
                logger?.debug("\(error.localizedDescription)")
                showAlert(withText: "Error importing IGC file: \(error.localizedDescription)")
            }
            return false
        }.result.get()
    }
    
    ///
    /// Exports an IGC file
    ///
    /// - Parameter flight: The flight to export
    func exportIgcFile(flight: Flight) async -> IgcFile? {
        do {
            return try await flightRecorder.exportFlight(flightToExport: flight)
        } catch {
            logger?.debug("\(error.localizedDescription)")
            showAlert(withText: "Failed to export flight")
        }
        return nil
    }
    
    ///
    /// Returns flights for logbook
    ///
    func getFlights() async -> [Flight] {
        let task = Task {
            do {
                return try await flightRecorder.getFlights()
            } catch {
                logger?.debug("\(error)")
                showAlert(withText: "Failed to load flights")
            }
            return [Flight]()
        }
        
        return await task.result.get()
    }
    
    ///
    /// Updates a stored flight's title
    ///
    /// - Parameter flightToUpdate: The flight to update the title for
    /// - Parameter newTitle: The new title to assign
    func updateFlightTitle(flightToUpdate flight: Flight, withTitle newTitle: String) {
        Task {
            do {
                try await flightRecorder.updateFlightTitle(forFlight: flight, withTitle: newTitle)
            } catch {
                logger?.debug("\(error)")
                showAlert(withText: "Error updating title")
            }
        }
    }
    
    ///
    /// Deletes a flight from CoreData
    ///
    /// - Parameter flight: The flight to delete
    func deleteFlight(_ flight: Flight) {
        Task {
            do {
                try await flightRecorder.deleteFlight(flight)
            } catch {
                logger?.debug("\(error)")
                showAlert(withText: "Failed to delete flight: \(flight.flightTitle ?? "Unknown")")
            }
        }
    }
}

///
/// Helper methods
///
extension XcCopilotViewModel {
    ///
    /// Shows an alert on screen
    ///
    /// - Parameter withText: The text to show
    func showAlert(withText alertText: String) {
        
        Task(priority: .userInitiated) {
            await MainActor.run {
                self.alertText = alertText
                self.alertShowing = true
            }
        }
        
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
    /// - Parameter elevationMetres: The input elevation to convert
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
