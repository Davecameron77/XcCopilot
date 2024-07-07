//
//  Flight+CoreDataProperties.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-07.
//
//

import Foundation
import CoreData


extension Flight {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Flight> {
        return NSFetchRequest<Flight>(entityName: "Flight")
    }

    @NSManaged public var cloudCover: Double
    @NSManaged public var dewpoint: Double
    @NSManaged public var dewpointUnit: String?
    @NSManaged public var finNumber: String?
    @NSManaged public var flightCopilot: String?
    @NSManaged public var flightDuration: String?
    @NSManaged public var flightEndDate: Date?
    @NSManaged public var flightFreeText: String?
    @NSManaged public var flightID: UUID?
    @NSManaged public var flightLocation: String?
    @NSManaged public var flightMaxLatitude: Double
    @NSManaged public var flightMaxLongitude: Double
    @NSManaged public var flightMinLatitude: Double
    @NSManaged public var flightMinLongitude: Double
    @NSManaged public var flightPilot: String?
    @NSManaged public var flightStartDate: Date?
    @NSManaged public var flightTitle: String?
    @NSManaged public var flightType: String?
    @NSManaged public var gliderName: String?
    @NSManaged public var gliderRegistration: String?
    @NSManaged public var gliderTrimSpeed: String?
    @NSManaged public var gpsDatum: String?
    @NSManaged public var gpsModel: String?
    @NSManaged public var gpsPrecision: Double
    @NSManaged public var humidity: Double
    @NSManaged public var igcID: String?
    @NSManaged public var landLatitude: Double
    @NSManaged public var landLongitude: Double
    @NSManaged public var launchLatitude: Double
    @NSManaged public var launchLongitude: Double
    @NSManaged public var pressure: Double
    @NSManaged public var pressureSensor: String?
    @NSManaged public var pressureUnit: String?
    @NSManaged public var temperature: Double
    @NSManaged public var temperatureUnit: String?
    @NSManaged public var varioFirmwareVer: String?
    @NSManaged public var varioHardwareVer: String?
    @NSManaged public var windDirection: String?
    @NSManaged public var windGust: Double
    @NSManaged public var windSpeed: Double
    @NSManaged public var windUnit: String?
    @NSManaged public var frames: NSOrderedSet?

}

// MARK: Generated accessors for frames
extension Flight {

    @objc(insertObject:inFramesAtIndex:)
    @NSManaged public func insertIntoFrames(_ value: FlightFrame, at idx: Int)

    @objc(removeObjectFromFramesAtIndex:)
    @NSManaged public func removeFromFrames(at idx: Int)

    @objc(insertFrames:atIndexes:)
    @NSManaged public func insertIntoFrames(_ values: [FlightFrame], at indexes: NSIndexSet)

    @objc(removeFramesAtIndexes:)
    @NSManaged public func removeFromFrames(at indexes: NSIndexSet)

    @objc(replaceObjectInFramesAtIndex:withObject:)
    @NSManaged public func replaceFrames(at idx: Int, with value: FlightFrame)

    @objc(replaceFramesAtIndexes:withFrames:)
    @NSManaged public func replaceFrames(at indexes: NSIndexSet, with values: [FlightFrame])

    @objc(addFramesObject:)
    @NSManaged public func addToFrames(_ value: FlightFrame)

    @objc(removeFramesObject:)
    @NSManaged public func removeFromFrames(_ value: FlightFrame)

    @objc(addFrames:)
    @NSManaged public func addToFrames(_ values: NSOrderedSet)

    @objc(removeFrames:)
    @NSManaged public func removeFromFrames(_ values: NSOrderedSet)

}

extension Flight : Identifiable {

}
