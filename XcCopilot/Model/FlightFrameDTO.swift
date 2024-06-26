//
//  FlightFrame.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreLocation
import CoreMotion
import SwiftData

@Model
class FlightFrameDTO {
    init(fromString line: String, andDate date: Date) {
        self.id = UUID().uuidString
        
        var dateComponents    = DateComponents()
        dateComponents.year   = date.get(.year)
        dateComponents.month  = date.get(.month)
        dateComponents.day    = date.get(.day)
        dateComponents.hour   = Int(line.subString(from: 1, to: 3).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.minute = Int(line.subString(from: 3, to: 5).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.second = Int(line.subString(from: 5, to: 7).trimmingCharacters(in: .whitespacesAndNewlines))
        self.timestamp        = Calendar.current.date(from: dateComponents)!
        
        let latDegrees        = abs(Double(line.subString(from: 7, to: 9))!)
        let latMinutes        = abs(Double(line.subString(from: 9, to: 11))! / 60)
        let latSecondsWhole   = abs(Double(line.subString(from: 11, to: 14))!) / 1000
        let latSeconds        = (latSecondsWhole * 60) / 3600
        let latDirection      = line.subString(from: 14, to: 15)
        var latitude          = latDegrees + latMinutes + latSeconds
        if latDirection == "S" {
            latitude *= -1
        }
        
        let longDegrees       = abs(Double(line.subString(from: 15, to: 18))!)
        let longMinutes       = abs(Double(line.subString(from: 18, to: 20))! / 60)
        let longSeocndsWhole  = abs(Double(line.subString(from: 20, to: 23))!) / 1000
        let longSeconds       = (longSeocndsWhole * 60) / 3600
        let longDirection     = line.subString(from: 23, to: 24)
        var longitude         = longDegrees + longMinutes + longSeconds
        if longDirection == "W" {
            longitude *= -1
        }
        
        let baroAlt           = Double(line.subString(from: 25, to: 30))!
        let gpsAlt            = Double(line.subString(from: 30, to: 35))!
        
        self.latitude            = latitude
        self.longitude           = longitude
        self.currentBaroAltitude = baroAlt
        self.currentGPSAltitude  = gpsAlt
    }
    
    init(
        pitchInDegrees: Double,
        rollInDegrees: Double,
        yawInDegrees: Double,
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalVelocity: Double
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date.now
        self.pitchInDegrees = pitchInDegrees
        self.rollInDegrees = rollInDegrees
        self.yawInDegrees = yawInDegrees
        self.accelerationX = acceleration.x
        self.accelerationY = acceleration.y
        self.accelerationZ = acceleration.z
        self.gravityX = gravity.x
        self.gravityY = gravity.y
        self.gravityZ = gravity.z
        self.currentGPSAltitude = gpsAltitude
        self.currentGPSCourse = gpsCourse
        self.latitude = gpsCoords.latitude
        self.longitude = gpsCoords.longitude
        self.currentBaroAltitude = baroAltitude
        self.currentVerticalVelocity = verticalVelocity
    }
    
    let id: String
    var timestamp: Date
    
    // Motion
    var pitchInDegrees: Double = 0.0
    var rollInDegrees: Double = 0.0
    var yawInDegrees: Double = 0.0
    var accelerationX: Double = 0.0
    var accelerationY: Double = 0.0
    var accelerationZ: Double = 0.0
    var gravityX: Double = 0.0
    var gravityY: Double = 0.0
    var gravityZ: Double = 0.0
    
    // GPS
    let currentGPSAltitude: Double = 0.0
    let currentGPSCourse: Double = 0.0
    let latitude: Double
    let longitude: Double
    
    // Barometer
    let currentBaroAltitude: Double
    let currentVerticalVelocity: Double = 0.0
    
    var flight: FlightDTO?
}
