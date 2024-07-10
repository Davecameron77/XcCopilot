//
//  FlightFrame.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-08.
//

import CoreMotion
import SwiftData
import Foundation

@Model
final class FlightFrame {
    
    init() {
        
    }
    
    init(
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalVelocity: Double
    ) {
        timestamp = Date.now
        accelerationX = acceleration.x
        accelerationY = acceleration.y
        accelerationZ = acceleration.z
        gravityX = gravity.x
        gravityY = gravity.y
        gravityZ = gravity.z
        currentGPSCourse = gpsCourse
        latitude = gpsCoords.latitude
        longitude = gpsCoords.longitude
        currentBaroAltitude = baroAltitude
        currentVerticalVelocity = verticalVelocity
    }
    
    // Id
    @Attribute(.unique) var id = UUID().uuidString
    var timestamp = Date.distantPast
    
    // Flight Vars
    var accelerationX = 0.0
    var accelerationY = 0.0
    var accelerationZ = 0.0
    var currentBaroAltitude = 0.0
    var currentGPSAltitude = 0.0
    var currentGPSCourse = 0.0
    var currentVerticalVelocity = 0.0
    var gravityX = 0.0
    var gravityY = 0.0
    var gravityZ = 0.0
    var latitude = 0.0
    var longitude = 0.0
    
    @Relationship(deleteRule: .deny) var flight: Flight?
}
