//
//  FlightFrame+CoreDataClass.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-06-26.
//
//

import Foundation
import CoreData
import CoreMotion
import CoreLocation

@objc(FlightFrame)
public class FlightFrame: NSManagedObject {
    
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
        currentBaroAltitude = baroAlt
        currentGPSAltitude = gpsAlt
    }
    

    func assignVars(
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalVelocity: Double,
        flightId: String
    ) {
        id = UUID()
        flightID = flightId
        timestamp = Date.now
        accelerationX = acceleration.x
        accelerationY = acceleration.y
        accelerationZ = acceleration.z
        gravityX = gravity.x
        gravityY = gravity.y
        gravityZ = gravity.z
        currentGPSAltitude = gpsAltitude
        currentGPSCourse = gpsCourse
        latitude = gpsCoords.latitude
        longitude = gpsCoords.longitude
        currentBaroAltitude = baroAltitude
        currentVerticalVelocity = verticalVelocity
    }
}
