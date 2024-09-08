//
//  CoreDataExtensions.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-11.
//

import CoreLocation
import CoreMotion
import Foundation
import WeatherKit

extension Flight {
        
    ///
    /// Used for displaying flight path on screen
    ///
    /// - Parameter forFrames: The frames to parse down to just coordinates
    /// - Returns Array of CLLocationCoordinate2D
    func returnFlightPath(forFrames frames: [FlightFrame]) -> [CLLocationCoordinate2D] {
        return frames.map({ CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
    }
    
    ///
    /// Used for displaying altitude profile in chart
    ///
    /// - Parameter forFrames: The frames to parse down to just altitude
    /// - Returns Array of altitudes
    func returnAltitudeHist(forFrames frames: [FlightFrame]) -> [Double] {
        return frames.map({ $0.baroAltitude })
    }
    
    ///
    /// Appends weather to a flight
    ///
    /// - Parameter weather: The weather to add
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
    
    static var dummyFlight: Flight {
        let flight = Flight()
        flight.id = UUID()
        flight.igcID = flight.id?.uuidString
        flight.title = "Dummy Flight"
        flight.gpsModel = "iphone 12 Pro"
        flight.gliderName = "Independance Pioneer"
        flight.pilot = "Dave Cameron"
        
        
        return flight
    }
        
}

extension FlightFrame {
            
    ///
    /// Returns the baro altitude padded for appending into IGC file
    ///
    ///- Returns a 5 character string with leading zeros
    func getBaroAltitudeForPrinting() -> String {
        var padding = "00000"
        
        switch baroAltitude {
        case 0...10:
            padding = "0000"
            break
        case 11...100:
            padding = "000"
            break
        case 101...1000:
            padding = "00"
            break
        case 1001...10000:
            padding = "0"
            break
        default:
            break
        }
        
        return padding + String(format: "%i", Int(baroAltitude))
    }
    
    ///
    /// Returns the GPS altitude padded for appending into IGC file
    ///
    ///- Returns a 5 character string with leading zeros
    func getGpsAltitudeForPrinting() -> String {
        var padding = "00000"
        
        switch gpsAltitude {
        case 0...10:
            padding = "0000"
            break
        case 11...100:
            padding = "000"
            break
        case 101...1000:
            padding = "00"
            break
        case 1001...10000:
            padding = "0"
            break
        default:
            break
        }
        
        return padding + String(format: "%i", Int(gpsAltitude))
    }
    
    static func dummyFrameFactory(_ line: String) -> FlightFrame {
        let frame = FlightFrame()
        frame.id = UUID()
        
        let hour = line.subString(from: 1, to: 3)
        let min = line.subString(from: 3, to: 5)
        let sec = line.subString(from: 5, to: 7)
                
        let latDegrees = abs(Double(line.subString(from: 7, to: 9))!)
        let latMinutes = abs(Double(line.subString(from: 9, to: 11))! / 60)
        let latSecondsWhole = abs(Double(line.subString(from: 11, to: 14))!) / 1000
        let latSeconds = (latSecondsWhole * 60) / 3600
        let latDirection = line.subString(from: 14, to: 15)
        let latitude = (latDegrees + latMinutes + latSeconds) * (latDirection == "S" ? -1 : 1)
        
        let longDegrees = abs(Double(line.subString(from: 15, to: 18))!)
        let longMinutes = abs(Double(line.subString(from: 18, to: 20))! / 60)
        let longSeocndsWhole = abs(Double(line.subString(from: 20, to: 23))!) / 1000
        let longSeconds = (longSeocndsWhole * 60) / 3600
        let longDirection = line.subString(from: 23, to: 24)
        let longitude = (longDegrees + longMinutes + longSeconds) * (longDirection == "W" ? -1 : 1)

        let baroAlt = line.subString(from: 25, to: 30)
        let gpsAlt = line.subString(from: 30, to: 35)
        
        var components = DateComponents()
        components.hour = Int(hour)
        components.minute = Int(min)
        components.second = Int(sec)
        components.year = 2024
        components.month = 9
        components.day = 1
        frame.timestamp = Calendar.current.date(from: components)
        
        frame.latitude = latitude
        frame.longitude = longitude
        
        frame.baroAltitude = Double(baroAlt) ?? 0.0
        frame.gpsAltitude = Double(gpsAlt) ?? 0.0
        
        return frame
    }
    
}
