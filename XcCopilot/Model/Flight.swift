//
//  Flight.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreLocation
import WeatherKit

class Flight: Identifiable {
    ///
    /// Basic Init
    ///
    init() {
        flightID = UUID()
        self.flightBoundaries = [CLLocationCoordinate2D]()
        self.flightFrames = [FlightFrame]()
        self.flightTitle = "Unknown Flight: \(flightID.uuidString.prefix(4))"
    }
    
    init(isDummy: Bool) {
        flightID = UUID()
        self.flightBoundaries = [CLLocationCoordinate2D]()
        self.flightFrames = [FlightFrame]()
        self.flightTitle = "Unknown Flight: \(flightID.uuidString.prefix(4))"
        self.flightStartDate = Date.now.addingTimeInterval(-120000)
        self.flightEndDate = Date.now.addingTimeInterval(-110000)
    }

    let flightID: UUID
    var flightTitle: String
    var flightStartDate: Date = Date.distantPast
    var flightEndDate: Date = Date.distantPast
    var flightDuration: TimeInterval {
        flightEndDate - flightStartDate
    }
    var flightLocation: String?
    var temperature: Measurement<UnitTemperature>?
    var humidity: Double = 0.0
    var dewpoint: Measurement<UnitTemperature>?
    var pressure: Measurement<UnitPressure>?
    var wind: Wind?
    var cloudCover: Double = 0.0
    var flightBoundaries: [CLLocationCoordinate2D]
    var flightFrames: [FlightFrame]
    
    static let dummyFlight = Flight(isDummy: true)
}
