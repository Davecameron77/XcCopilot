//
//  Flight+CoreDataProperties.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-08-16.
//
//

import Foundation
import CoreData


extension Flight {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Flight> {
        return NSFetchRequest<Flight>(entityName: "Flight")
    }

    @NSManaged public var cloudCover: Double
    @NSManaged public var copilot: String?
    @NSManaged public var dewpoint: Double
    @NSManaged public var dewpointUnit: String?
    @NSManaged public var duration: String?
    @NSManaged public var endDate: Date?
    @NSManaged public var finNumber: String?
    @NSManaged public var freeText: String?
    @NSManaged public var gliderName: String?
    @NSManaged public var gliderRegistration: String?
    @NSManaged public var gliderTrimSpeed: String?
    @NSManaged public var gpsDatum: String?
    @NSManaged public var gpsModel: String?
    @NSManaged public var gpsPrecision: Double
    @NSManaged public var humidity: Double
    @NSManaged public var id: UUID?
    @NSManaged public var igcID: String?
    @NSManaged public var imported: Bool
    @NSManaged public var landLatitude: Double
    @NSManaged public var landLongitude: Double
    @NSManaged public var launchLatitude: Double
    @NSManaged public var launchLongitude: Double
    @NSManaged public var location: String?
    @NSManaged public var maxLatitude: Double
    @NSManaged public var maxLongitude: Double
    @NSManaged public var minLatitude: Double
    @NSManaged public var minLongitude: Double
    @NSManaged public var pilot: String?
    @NSManaged public var pressure: Double
    @NSManaged public var pressureSensor: String?
    @NSManaged public var pressureUnit: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var temperature: Double
    @NSManaged public var temperatureUnit: String?
    @NSManaged public var title: String?
    @NSManaged public var type: String?
    @NSManaged public var varioFirmwareVer: String?
    @NSManaged public var varioHardwareVer: String?
    @NSManaged public var windDirection: String?
    @NSManaged public var windGust: Double
    @NSManaged public var windSpeed: Double
    @NSManaged public var windUnit: String?
    @NSManaged public var frames: NSSet?

}

// MARK: Generated accessors for frames
extension Flight {

    @objc(addFramesObject:)
    @NSManaged public func addToFrames(_ value: FlightFrame)

    @objc(removeFramesObject:)
    @NSManaged public func removeFromFrames(_ value: FlightFrame)

    @objc(addFrames:)
    @NSManaged public func addToFrames(_ values: NSSet)

    @objc(removeFrames:)
    @NSManaged public func removeFromFrames(_ values: NSSet)

}

extension Flight : Identifiable {

}
