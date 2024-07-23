//
//  FlightFrame+CoreDataProperties.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-20.
//
//

import Foundation
import CoreData


extension FlightFrame {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FlightFrame> {
        return NSFetchRequest<FlightFrame>(entityName: "FlightFrame")
    }

    @NSManaged public var accelerationX: Double
    @NSManaged public var accelerationY: Double
    @NSManaged public var accelerationZ: Double
    @NSManaged public var baroAltitude: Double
    @NSManaged public var gpsAltitude: Double
    @NSManaged public var gpsCourse: Double
    @NSManaged public var verticalSpeed: Double
    @NSManaged public var flightID: String?
    @NSManaged public var gravityX: Double
    @NSManaged public var gravityY: Double
    @NSManaged public var gravityZ: Double
    @NSManaged public var id: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var latitudeDegrees: Int64
    @NSManaged public var latitudeMinutes: Int64
    @NSManaged public var latitudeSeconds: Int64
    @NSManaged public var longitude: Double
    @NSManaged public var longitudeDegrees: Int64
    @NSManaged public var longitudeMinutes: Int64
    @NSManaged public var longitudeSeconds: Int64
    @NSManaged public var timestamp: Date?
    @NSManaged public var derrivedVerticalSpeed: Double
    @NSManaged public var flight: Flight?

}

extension FlightFrame : Identifiable {

}
