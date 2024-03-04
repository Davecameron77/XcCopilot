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
class FlightFrame {
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
        self.id = UUID()
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
    
    let id: UUID
    var timestamp: Date
    
    // Motion
    var pitchInDegrees: Double
    var rollInDegrees: Double
    var yawInDegrees: Double
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var gravityX: Double
    var gravityY: Double
    var gravityZ: Double
    
    // GPS
    let currentGPSAltitude: Double
    let currentGPSCourse: Double
    let latitude: Double
    let longitude: Double
    
    // Barometer
    let currentBaroAltitude: Double
    let currentVerticalVelocity: Double
    
    var flight: Flight?
}

