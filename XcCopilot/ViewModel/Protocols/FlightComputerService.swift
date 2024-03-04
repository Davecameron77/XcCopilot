//
//  FlightComputerService.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import CoreMotion

protocol FlightComputerService {
    var delegate: ViewModelDelegate? { get set }
    
    var inFlight: Bool { get set }
    var readyToFly: Bool { get }
    
    var gpsAltitude: Double { get }
    var gpsSpeed: Double { get }
    var gpsCourse: Double { get }
    var magneticHeading: Double { get }
    var currentCoords: CLLocationCoordinate2D { get }
    
    var pitchInDegrees: Double { get }
    var rollInDegrees: Double { get }
    var yawInDegrees: Double { get }
    var acceleration: CMAcceleration { get }
    var gravity: CMAcceleration { get }
    
    var baroAltitude: Double { get }
    var terrainElevation: Double { get }
    var calculatedElevation: Double { get }
    var glideRangeInMetres: Double { get }
    var verticalVelocityMetresPerSecond: Double { get }
    var verticalAccelerationMetresPerSecondSquared: Double { get }
    var headingToNearestThermal: Double { get }
    var distanceToNearestThermal: Double { get }
    var flightTime: TimeInterval { get }
    
    func startFlying()
    func stopFlying()
}

