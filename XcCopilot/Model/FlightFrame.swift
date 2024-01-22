//
//  FlightFrame.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreLocation
import CoreMotion

struct FlightFrame {
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
        self.currentAcceleration = acceleration
        self.currentGravity = gravity
        self.currentGPSAltitude = gpsAltitude
        self.currentGPSCourse = gpsCourse
        self.currentGPSCoords = gpsCoords
        self.currentBaroAltitude = baroAltitude
        self.currentVerticalVelocity = verticalVelocity
    }
    
    let id: UUID
    let timestamp: Date
    // Motion
    let pitchInDegrees: Double
    let rollInDegrees: Double
    let yawInDegrees: Double
    let currentAcceleration: CMAcceleration
    let currentGravity: CMAcceleration
    
    // GPS
    let currentGPSAltitude: Double
    let currentGPSCourse: Double
    let currentGPSCoords: CLLocationCoordinate2D
    
    // Barometer
    let currentBaroAltitude: Double
    let currentVerticalVelocity: Double
}

