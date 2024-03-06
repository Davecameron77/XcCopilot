//
//  Flight.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreLocation
import WeatherKit
import SwiftData

@Model
class Flight {
    ///
    /// Basic Init
    ///
    init() {
        let id            = UUID().uuidString
        flightID          = id
        self.flightFrames = []
        self.flightTitle  = "Unknown Flight: \(id.prefix(4))"
    }
    
    ///
    /// Init for dummy flight
    ///
    init(isDummy: Bool) {
        let id = UUID().uuidString
        flightID = id
        self.flightStartDate  = Date.now.addingTimeInterval(-120000)
        self.flightEndDate    = Date.now.addingTimeInterval(-110000)
        self.flightTitle      = "Unknown Flight: \(id.prefix(4))"
        self.flightFrames     = []
    }

    let flightID: String
    var igcID: String?
    var flightTitle: String
    var flightStartDate: Date = Date.distantPast
    var flightEndDate: Date = Date.distantFuture
    var flightDuration: String = "00:00:00"
    var launchLatitude: Double = 0.0
    var launchLongitude: Double = 0.0
    var landLatitude: Double = 0.0
    var landLongitude: Double = 0.0
    var flightLocation: String?
    
    // Weather vars
    var temperature: Double = 0.0
    var temperatureUnit: String?
    var humidity: Double = 0.0
    var dewpoint: Double = 0.0
    var dewpointUnit: String?
    var pressure: Double = 0.0
    var pressureUnit: String?
    var windSpeed: Double = 0.0
    var windGust: Double = 0.0
    var windDirection: Double = 0.0
    var windUnit: String?
    var cloudCover: Double = 0.0
    
    var flightMinLatitude: Double = 0.0
    var flightMaxLatitude: Double = 0.0
    var flightMinLongitude: Double = 0.0
    var flightMaxLongitude: Double = 0.0
    
    // Don't really need these
    var gpsPrecision: Int?
    var gpsDatum: String = "WGS84"
    var varioFirmwareVer: String?
    var varioHardwareVer: String?
    var flightType: String?
    var gpsModel: String?
    var pressureSensor: String?
    var finNumber: String?
    var flightFreeText: String?
    var flightPilot: String?
    var flightCopilot: String?
    
    // Swift Data Relationships
    var gliderName: String?
    var gliderTrimSpeed: Double = 0.0
    var gliderRegistration: String?
    
    @Relationship(deleteRule: .cascade) var flightFrames: [FlightFrame]
    
    static let dummyFlight = Flight(isDummy: true)
}
