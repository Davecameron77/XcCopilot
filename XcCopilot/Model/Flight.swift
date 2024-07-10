//
//  Flight.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-08.
//

import CoreLocation
import Foundation
import SwiftData
import WeatherKit

@Model
final class Flight {
    init() {
        
    }
    
    // ID
    @Attribute(.unique) var id = UUID().uuidString
    var igcID = ""
    
    // Flight Vars
    var flightDuration = "00:00:00"
    var flightEndDate: Date?
    var flightMaxLatitude = 0.0
    var flightMaxLongitude = 0.0
    var flightMinLatitude = 0.0
    var flightMinLongitude = 0.0
    var flightStartDate: Date?
    var landLatitude = 0.0
    var landLongitude = 0.0
    var launchLatitude = 0.0
    var launchLongitude = 0.0
    
    // Meta
    var finNumber = ""
    var flightCopilot = ""
    var flightFreeText = ""
    var flightLocation = ""
    var flightPilot = ""
    var flightTitle = "Unknown Flight"
    var flightType = ""
    var gliderName = ""
    var gliderRegistration = ""
    var gliderTrimSpeed = ""
    var gpsDatum = ""
    var gpsModel = ""
    var gpsPrecision = 0.0
    var varioFirmwareVer = ""
    var varioHardwareVer = ""
        
    // Weather
    var cloudCover = 0.0
    var dewpoint = 0.0
    var dewpointUnit = ""
    var humidity = 0.0
    var pressure = 0.0
    var pressureSensor = ""
    var pressureUnit = ""
    var temperature = 0.0
    var temperatureUnit = ""
    var windDirection = ""
    var windGust = 0.0
    var windSpeed = 0.0
    var windUnit = ""
    
    @Relationship(deleteRule: .cascade) var frames = [FlightFrame]()
    
    ///
    /// Used for displaying flight on screen
    ///
    func returnFlightPath(forFrames frames: [FlightFrame]) -> [CLLocationCoordinate2D] {
        return frames.map({ CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
    }
    
    ///
    /// Used for displaying flight on screen
    ///
    func returnAltitudeHist(forFrames frames: [FlightFrame]) -> [Double] {
        return frames.map({ $0.currentBaroAltitude })
    }
    
    ///
    /// Appends weather to a flight
    ///
    func addWeather(_ weather: Weather) {
        temperature = weather.currentWeather.temperature.value
        humidity = weather.currentWeather.humidity.magnitude
        dewpoint = weather.currentWeather.dewPoint.value
        pressure = weather.currentWeather.pressure.value
        windSpeed = weather.currentWeather.wind.speed.value
        windGust = weather.currentWeather.wind.gust?.value ?? 0.0
        windDirection = weather.currentWeather.wind.compassDirection.abbreviation
    }
    
    func addFrame(_ frame: FlightFrame) {
        frames.append(frame)
    }
}
