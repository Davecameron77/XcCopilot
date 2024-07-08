//
//  Flight+CoreDataClass.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-06-26.
//
//

import Foundation
import CoreData
import CoreLocation
import WeatherKit

@objc(Flight)
public class Flight: NSManagedObject {

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
    func addWeather(weather: Weather?) {
        guard weather != nil else { return }
        temperature = weather!.currentWeather.temperature.value
        humidity = weather!.currentWeather.humidity.magnitude
        dewpoint = weather!.currentWeather.dewPoint.value
        pressure = weather!.currentWeather.pressure.value
        windSpeed = weather!.currentWeather.wind.speed.value
        windGust = weather!.currentWeather.wind.gust?.value ?? 0.0
        windDirection = weather!.currentWeather.wind.compassDirection.abbreviation
    }

}
