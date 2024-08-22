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
    /// Used for displaying flight on screen
    ///
    func returnFlightPath(forFrames frames: [FlightFrame]) -> [CLLocationCoordinate2D] {
        return frames.map({ CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
    }
    
    ///
    /// Used for displaying flight on screen
    ///
    func returnAltitudeHist(forFrames frames: [FlightFrame]) -> [Double] {
        return frames.map({ $0.baroAltitude })
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

extension FlightFrame {
    func processIgcString(withString line: String, andDate date: Date, andFlightId flightId: String) {
        id = UUID()
        flightID = flightId
        
        var dateComponents = DateComponents()
        dateComponents.year = date.get(.year)
        dateComponents.month = date.get(.month)
        dateComponents.day = date.get(.day)
        dateComponents.hour = Int(line.subString(from: 1, to: 3).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.minute = Int(line.subString(from: 3, to: 5).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.second = Int(line.subString(from: 5, to: 7).trimmingCharacters(in: .whitespacesAndNewlines))
        timestamp = Calendar.current.date(from: dateComponents)!
        
        let latDegrees = abs(Double(line.subString(from: 7, to: 9))!)
        let latMinutes = abs(Double(line.subString(from: 9, to: 11))! / 60)
        let latSecondsWhole = abs(Double(line.subString(from: 11, to: 14))!) / 1000
        let latSeconds = (latSecondsWhole * 60) / 3600
        let latDirection = line.subString(from: 14, to: 15)
        var calculatedLat = latDegrees + latMinutes + latSeconds
        if latDirection == "S" {
            calculatedLat *= -1
        }
        
        let longDegrees = abs(Double(line.subString(from: 15, to: 18))!)
        let longMinutes = abs(Double(line.subString(from: 18, to: 20))! / 60)
        let longSeocndsWhole = abs(Double(line.subString(from: 20, to: 23))!) / 1000
        let longSeconds = (longSeocndsWhole * 60) / 3600
        let longDirection = line.subString(from: 23, to: 24)
        var calculatedLong = longDegrees + longMinutes + longSeconds
        if longDirection == "W" {
            calculatedLong *= -1
        }
        
        let baroAlt = Double(line.subString(from: 25, to: 30))!
        let gpsAlt = Double(line.subString(from: 30, to: 35))!
        
        latitude = calculatedLat
        longitude = calculatedLong
        baroAltitude = baroAlt
        gpsAltitude = gpsAlt
    }
    
    func assignVars(
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalSpeed: Double
    ) {
        id = UUID()
        timestamp = Date.now
        accelerationX = acceleration.x
        accelerationY = acceleration.y
        accelerationZ = acceleration.z
        gravityX = gravity.x
        gravityY = gravity.y
        gravityZ = gravity.z
        self.gpsAltitude = gpsAltitude
        self.gpsCourse = gpsCourse
        latitude = gpsCoords.latitude
        longitude = gpsCoords.longitude
        let latDms = gpsCoords.latitude.toDegreesMinutesSeconds()
        let longDms = gpsCoords.longitude.toDegreesMinutesSeconds()
        latitudeDegrees = Int64(latDms.0)
        latitudeMinutes = Int64(latDms.1)
        latitudeSeconds = Int64(latDms.2)
        longitudeDegrees = Int64(longDms.0)
        longitudeMinutes = Int64(longDms.1)
        longitudeSeconds = Int64(longDms.2)
        self.baroAltitude = baroAltitude
        self.verticalSpeed = verticalSpeed
    }
    
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
}
