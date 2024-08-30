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
    @Published var verticalAccelerationMps2 = 0.0
    
    // GPS
    @Published var gpsCoords = CLLocationCoordinate2D.init(latitude: 0.0, longitude: 0.0)
    @Published var gpsAltitude = 0.0
    @Published var gpsSpeed = 0.0
    @Published var gpsCourse = 0.0
    
    // Altimeter
    @Published var baroAltitude = 0.0
    @Published var calculatedElevation = 0.0
    @Published var verticalSpeedMps = 0.0
    @Published var glideRatio = 1.0
    @Published var glideRangeInMetres = 0.0
    @Published var glideRangeInPixels = 0.0
    @Published var nearestThermalHeading = 0.0
    @Published var nearestThermalDistance = 0.0
        
    // Permissions
    @Published var altAvailable = false
    @Published var gpsAvailable = false
    @Published var motionAvailable = false
    
    // Compass
    @Published var magneticHeading = 0.0
    
    // Wind
    @Published var windSpeed: Double = 0.0
    @Published var windDirection: Double = 0.0
    
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
    
    
    // Logbook
    @Published var flightsInLogbook: [Flight] = []
    
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
    @AppStorage("pilotName") var pilotName: String = "Dave Cameron" {
        willSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    @AppStorage("gliderName") var gliderName: String = "Independance Pioneer" {
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
    
    private let REFRESH_FREQUENCY = 1.0
    private var updateTimer: Timer?
    
    private var currentWeatherTimestamp = Date.distantPast
    var readyToFly: Bool { flightComputer.readyToFly }
    var flightComputer: FlightComputerService
    var flightRecorder: FlightRecorder
    var flightAnalzyer: FlightAnalyzer
    let weatherService = WeatherService()
    
    ///
    /// Init a new ViewModel with default properties
    ///
    init() {
        mapPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: cameraBackup)
        
//        flightComputer = ReplayComputer()
        flightComputer = FlightComputer()
        flightRecorder = FlightRecorder()
        flightAnalzyer = FlightAnalyzer()
        
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
            do {
                try flightRecorder.armForFlight()
            } catch {
                logger?.debug("Error arming for flight: \(error)")
                showAlert(withText: "Error arming for flight")
            }
            
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
            logger?.debug("Error starting flight: \(error)")
            showAlert(withText: "Error starting flight")
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
                try await flightRecorder.endFlight(withWeather: currentWeather, pilot: pilotName, glider: gliderName)
                await MainActor.run {
                    flightTime = .zero
                }
            } catch {
                showAlert(withText: "Error stopping flight")
                logger?.debug("Error stopping flight: \(error)")
            }
        }
    }
    
    ///
    /// Updates VM flight vars for display in the GUI
    ///
    func updateFlightVars() {
        
        Task(priority: .high) {
            await MainActor.run {
                verticalSpeedMps = flightComputer.verticalSpeedMps
                verticalAccelerationMps2 = flightComputer.verticalAccelerationMps2
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
                
                windSpeed = speedUnits(speedMetresSecond: flightComputer.relativeWindSpeed)
                windDirection = flightComputer.relativeWindDirection
                
                // Flight specific tracking
                if flightState == .inFlight {
                    nearestThermalHeading = flightComputer.headingToNearestThermal
                    nearestThermalDistance = flightComputer.distanceToNearestThermal
                    
                    flightTime = Duration.seconds(flightComputer.flightTime)
                    
                    playVarioSound()
                }
            }
        }
        
        
        // Detect a launch
        if flightState == .armed && gpsSpeed > 5.0 {
            startFlying()
        }

        // Detect a landing
        if flightState == .inFlight && gpsSpeed < 1.0 && calculatedElevation < 10.0  && flightComputer.flightTime > 30.0 {
            #if targetEnvironment(simulator)
            
            #else
            stopFlying()
            #endif
        }
    }
    
    ///
    /// Plays tones based on current vertical velocity
    ///
    func playVarioSound() {
        if !audioActive { return }
        
        switch verticalSpeedMps {
        case -100 ..< -4.0:
            // Play at 6hz
            SoundManager.shared.playTone(forFrequency: .sixHzDescend)
        case -4.0 ..< -1.5:
            // Play at 4hz
            SoundManager.shared.playTone(forFrequency: .fourHzDescend)
        case -1.5 ..< -1.0:
            // Play at 2hz
            SoundManager.shared.playTone(forFrequency: .twoHzDescend)
        case -0.1 ..< 0.5:
            // Trivial vertical motion
            return
        case 0.5 ..< 2.0:
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
            Task {
                let location = CLLocation(
                    latitude: flightComputer.currentCoords.latitude,
                    longitude: flightComputer.currentCoords.longitude
                )
                
                do {
                    let weather = try await weatherService.weather(for: location)
                    await MainActor.run {
                        currentWeather = weather
                        currentWeatherTimestamp = Date.now
                    }
                } catch {
                    logger?.debug("Error fetching weather: \(error)")
                    showAlert(withText: "Error fetching weather")
                }
                
            }
        }
    }

    ///
    /// Logs a flight frame with the FlightRecorderService
    ///
    func logFlightFrame() {
        // Log flight
        if flightComputer.inFlight {
            Task(priority: .medium) {
                do {
                    try flightRecorder.storeActiveFrame(
                        acceleration: flightComputer.acceleration,
                        gravity: flightComputer.gravity,
                        gpsAltitude: gpsAltitude,
                        gpsCourse: gpsCourse,
                        gpsCoords: gpsCoords,
                        baroAltitude: baroAltitude,
                        verticalVelocity: verticalSpeedMps
                    )
                } catch {
                    logger?.debug("Error creating frame: \(error.localizedDescription)")
                }
            }
        }
    }
    
    ///
    /// Imports an IGC file
    ///
    /// - Parameter forUrl: The file to import
    ///
    /// - Returns true on success
    func importIgcFile(forUrl url: URL) async -> Bool {
        let task = Task(priority: .background) {
            do {
                try await flightRecorder.importFlight(forUrl: url)
                showAlert(withText: "\(url.lastPathComponent) imported")
                return true
            } catch {
                logger?.debug("\(error.localizedDescription)")
                showAlert(withText: "Error importing IGC file: \(error.localizedDescription)")
            }
            return false
        }
        
        return await task.result.get()
    }
    
    ///
    /// Exports an IGC file
    ///
    /// - Parameter flight: The flight to export
    ///
    /// - Returns IgcFile: Optional if the export was successful
    func exportIgcFile(flight: Flight) async -> IgcFile? {
        let task = Task(priority: .background) {
            do {
                return try await flightRecorder.exportFlight(flightToExport: flight)
            } catch {
                logger?.debug("\(error.localizedDescription)")
                showAlert(withText: "Failed to export flight")
            }
            return nil
        }
        
        return await task.result.get()
    }
    
    ///
    /// Returns flights for logbook
    ///
    ///
    /// - Returns A list of found flights
    func getFlights() async throws -> [Flight] {
        do {
            return try flightRecorder.getFlights()
        } catch {
            logger?.debug("\(error.localizedDescription)")
            showAlert(withText: "Failed to fetch flights")
        }
        return [Flight]()
    }
    
    ///
    /// Returns flights around given region for analysis view
    ///
    /// - Parameter region: The region to search
    /// - Parameter withSpan: The span to search around the region
    ///
    /// - Returns A list of found flights
    func getFlightsAroundRegion(_ region: CLLocationCoordinate2D, withSpan span: MKCoordinateSpan) async -> [Flight] {
        do {
            return try flightRecorder.getFlightsAroundCoords(region, withSpan: span)
        } catch {
            logger?.debug("\(error.localizedDescription)")
            showAlert(withText: "Failed to fetch flights")
        }
        return [Flight]()
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
                try flightRecorder.deleteFlight(flight)
            } catch {
                logger?.debug("\(error)")
                showAlert(withText: "Failed to delete flight: \(flight.title ?? "Unknown")")
            }
        }
    }
    
    ///
    /// Forwards a request to analyze flights
    ///
    /// - Parameter : Array of flights to analyze
    /// - Parameter withinSpan: The area to search
    ///
    /// - Returns an optional DmsQuadtree with results if they are found
    func analyzeFlights(
        _ flights: [Flight],
        aroundCoords coords: CLLocationCoordinate2D,
        withinSpan span: MKCoordinateSpan
    ) -> DmsQuadtree? {
        do {
            let tree = try flightAnalzyer.analyzeStoredFlights(flights, aroundCoords: coords, withinSpan: span)
            if tree.divided || tree.points.count > 0 {
                return tree
            } else {
                showAlert(withText: "No data found for provided flights")
            }
        } catch {
            logger?.debug("Flight Analyzer error: \(error)")
            showAlert(withText: error.localizedDescription)
        }
        
        return nil
    }
    
    ///
    /// Calculates the glide range to display on the map according to map scale
    ///
    /// - Parameter forContext: The map to measure from
    /// - Parameter withGeometry: The screen geometry to use
    func calculateGlideRangeToDisplay(forContext context: MapCameraUpdateContext,
                                      withGeometry geometry: GeometryProxy) {
        
        let center = context.camera.centerCoordinate
        let span = context.region.span
        
        // Top reference of map
        let topOfMap = CLLocation(latitude: center.latitude - span.latitudeDelta * 0.5,
                                  longitude: center.longitude)
        // Bottom reference of map
        let bottomOfMap = CLLocation(latitude: center.latitude + span.latitudeDelta * 0.5,
                                     longitude: center.longitude)
        // Map height in Meters
        let screenHeightMeters = Measurement(value: topOfMap.distance(from: bottomOfMap),
                                             unit: UnitLength.meters).value
        
        let pxPerMeter = geometry.size.height / screenHeightMeters
        glideRangeInPixels = glideRangeInMetres * pxPerMeter
        glideRangeInPixels = glideRangeInPixels > 0 ? glideRangeInPixels : 1
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
    
    ///
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
    
    ///
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
    
    ///
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
