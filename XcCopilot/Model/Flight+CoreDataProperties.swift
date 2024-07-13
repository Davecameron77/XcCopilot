//
//  Flight+CoreDataProperties.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-11.
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
    @NSManaged public var id: UUID?
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

}

extension Flight : Identifiable {

}
