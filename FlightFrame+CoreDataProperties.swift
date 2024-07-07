//
//  FlightFrame+CoreDataProperties.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-07.
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
    @NSManaged public var currentBaroAltitude: Double
    @NSManaged public var currentGPSAltitude: Double
    @NSManaged public var currentGPSCourse: Double
    @NSManaged public var currentVerticalVelocity: Double
    @NSManaged public var flightID: String?
    @NSManaged public var gravityX: Double
    @NSManaged public var gravityY: Double
    @NSManaged public var gravityZ: Double
    @NSManaged public var id: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var flight: Flight?

}

extension FlightFrame : Identifiable {

}
