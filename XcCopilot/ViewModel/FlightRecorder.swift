//
//  FlightRecorder.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-30.
//

import CoreData
import CoreLocation
import CoreMotion
import MapKit
import SwiftUI
import UniformTypeIdentifiers
import WeatherKit

class FlightRecorder: FlightRecorderService {
    
    var delegate: (any ViewModelDelegate)?
    var flight: Flight?
    static var flightDate: Date = Date.now
    
    ///
    /// Enables takeoff detection and passes a reference of the flight to record
    ///
    func armForFlight() throws {
        flight = Flight(context: CoreDataManager.shared.privateContext)
        guard flight != nil else { throw FlightRecorderError.invalidState("No flight assigned for recording") }
        
        flight!.id = UUID()
        flight!.igcID = flight!.id!.uuidString
        flight!.title = Date.now.formatted(date: .abbreviated, time: .omitted)
        
        if CoreDataManager.shared.privateContext.hasChanges || CoreDataManager.shared.viewContext.hasChanges {
            try CoreDataManager.shared.privateContext.save()
            try CoreDataManager.shared.viewContext.save()
        }
    }
    
    
    ///
    /// Stores a frame recorded by the flight computer
    ///
    /// - Parameter acceleration: The acceleration to store
    /// - Parameter gravity: The gravity to store
    /// - Parameter gpsAltitude: The GPS altitude to store
    /// - Parameter gpsCourse: The GPS course to store
    /// - Parameter gpsCoords: The GPS coords to store
    /// - Parameter gpsSpeed: The GPS speed to store
    /// - Parameter baroAltitude: The barometric altitude to store
    /// - Parameter verticalVelocity: The calculated vertical velocity to store
    func createAndStoreFrame(acceleration: CMAcceleration, gravity: CMAcceleration, gpsAltitude: Double,
                             gpsCourse: Double, gpsCoords: CLLocationCoordinate2D, gpsSpeed: Double,
                             baroAltitude: Double, verticalVelocity: Double) throws {
        
        guard flight != nil else { throw FlightRecorderError.invalidState("No flight assigned for recording") }
        
        let frame = FlightFrame(context: CoreDataManager.shared.privateContext)
        frame.id = UUID()
        frame.flight = flight
        frame.flightID = flight!.igcID
        frame.timestamp = Date.now
        frame.accelerationX = acceleration.x
        frame.accelerationY = acceleration.y
        frame.accelerationZ = acceleration.z
        frame.gravityX = gravity.x
        frame.gravityY = gravity.y
        frame.gravityZ = gravity.z
        frame.gpsAltitude = gpsAltitude
        frame.gpsCourse = gpsCourse
        frame.latitude = gpsCoords.latitude
        frame.longitude = gpsCoords.longitude
        frame.gpsSpeed = gpsSpeed
        frame.baroAltitude = baroAltitude
        frame.verticalSpeed = verticalVelocity
        
        if CoreDataManager.shared.privateContext.hasChanges || CoreDataManager.shared.viewContext.hasChanges {
            try CoreDataManager.shared.privateContext.save()
            try CoreDataManager.shared.viewContext.save()
        }
    }
    
    ///
    /// Ends a flight, calculating metadata
    ///
    /// - Parameter withWeather: The weather to append
    /// - Parameter pilot: The pilots name
    /// - Parameter glider: The model of glider
    func endFlight(withWeather weather: Weather?, pilot pilotName: String = "Unknown Pilot", glider gliderName: String = "Unnamed Glider") async throws {
        guard flight != nil else { throw CdError.recordingFailure("Failed to conclude flight") }
        
        let frames = (flight!.frames?.allObjects as! [FlightFrame]).sorted(by: { $0.timestamp! < $1.timestamp! })
        guard frames.count > 0 else { throw CdError.recordingFailure("No frames found for flight") }
        
        // Start / End Duration
        flight!.startDate = frames.first!.timestamp
        flight!.endDate = frames.last!.timestamp
        
        let interval = frames.last!.timestamp!.timeIntervalSince(frames.first!.timestamp!)
        flight!.duration = interval.hourMinuteSecond
        
        // Launch / Land
        flight!.launchLatitude = frames.first!.latitude
        flight!.launchLongitude = frames.first!.longitude
        flight!.landLatitude = frames.last!.latitude
        flight!.landLongitude = frames.last!.longitude
        
        // Derrived vertical speed
        for index in 0...frames.count - 1 {
            var derrivedVerticalSpeed = 0.0
            
            if index == 0 {
                derrivedVerticalSpeed = 0.0
            } else if index == 1 {
                derrivedVerticalSpeed = frames[index].baroAltitude - frames[index-1].baroAltitude
            } else if index == 2 {
                var delta = 0.0
                delta += frames[index].baroAltitude - frames[index-1].baroAltitude
                delta += frames[index-1].baroAltitude - frames[index-2].baroAltitude
                
                derrivedVerticalSpeed = delta / 2.0
            } else if index == 3 {
                var delta = 0.0
                delta += frames[index].baroAltitude - frames[index-1].baroAltitude
                delta += frames[index-1].baroAltitude - frames[index-2].baroAltitude
                delta += frames[index-2].baroAltitude - frames[index-3].baroAltitude
                
                derrivedVerticalSpeed = delta / 3.0
            } else {
                var delta = 0.0
                delta += frames[index].baroAltitude - frames[index-1].baroAltitude
                delta += frames[index-1].baroAltitude - frames[index-2].baroAltitude
                delta += frames[index-2].baroAltitude - frames[index-3].baroAltitude
                delta += frames[index-3].baroAltitude - frames[index-4].baroAltitude
                
                derrivedVerticalSpeed = delta / 4.0
            }
            
            frames[index].derrivedVerticalSpeed = derrivedVerticalSpeed
        }
        
        // Boundaries
        flight!.maxLatitude = frames.max(by: { $0.latitude < $1.latitude })?.latitude ?? 0.0
        flight!.minLatitude = frames.min(by: { $0.latitude < $1.latitude })?.latitude ?? 0.0
        flight!.maxLongitude = frames.max(by: { $0.longitude < $1.longitude })?.longitude ?? 0.0
        flight!.minLongitude = frames.min(by: { $0.longitude < $1.longitude })?.longitude ?? 0.0
                
        // Meta
        flight!.varioHardwareVer = "iPhone"
        flight!.varioFirmwareVer = ""
        flight!.gpsModel = "iPhone"
        flight!.pilot = pilotName
        flight!.gliderName = gliderName
        
        // Weather
        if weather != nil {
            flight!.addWeather(weather: weather!)
        }
        
        if CoreDataManager.shared.privateContext.hasChanges || CoreDataManager.shared.viewContext.hasChanges {
            try CoreDataManager.shared.privateContext.save()
            try CoreDataManager.shared.viewContext.save()
        }
    }
}

// Logbook
extension FlightRecorder {
    ///
    /// Returns a list of all flights
    ///
    /// - Returns an array of all stored flights
    func getFlights() async throws -> [Flight] {
        let request = Flight.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        return try CoreDataManager.shared.privateContext.fetch(request)
    }
    
    ///
    /// Returns flights that took off within the given region
    ///
    /// - Parameter coords: The centre coordinates to search
    /// - Parameter withSpan: The distance from centre to search
    /// - Returns a lis tof flights within the specified region
    func getFlightsAroundCoords(_ coords: CLLocationCoordinate2D, withSpan span: MKCoordinateSpan) async throws -> [Flight] {
        
        let latSpan = span.latitudeDelta
        let longSpan = span.longitudeDelta
        
        var minLat, maxLat, minLong, maxLong: Double
        let multiplier = 1.5
        
        if coords.latitude > 0 {
            maxLat = coords.latitude + latSpan * multiplier
            minLat = coords.latitude - latSpan * multiplier
        } else {
            maxLat = coords.latitude + latSpan * multiplier
            minLat = coords.latitude - latSpan * multiplier
        }
        
        if coords.longitude > 0 {
            maxLong = coords.longitude + longSpan * multiplier
            minLong = coords.longitude - longSpan * multiplier
        } else {
            maxLong = coords.longitude + longSpan * multiplier
            minLong = coords.longitude - longSpan * multiplier
        }
        
        
        let predicate = NSPredicate(
            format: "launchLatitude >= %f AND launchLatitude <= %f AND launchLongitude >= %f AND launchLongitude <= %f",
            minLat,
            maxLat,
            minLong,
            maxLong
        )
        
        let request = Flight.fetchRequest()
        request.predicate = predicate
        
        return try CoreDataManager.shared.privateContext.fetch(request)
    }
    
    ///
    /// Returns a stored flight with the given igcId
    ///
    /// - Parameter withIgcId: The id of the flight to load
    /// - Returns a single flight with the given IGC ID if found, else nil
    private func getFlight(withIgcId igcID: String) async throws -> Flight? {
        let query = Flight.fetchRequest()
        let predicate = NSPredicate(format: "igcID == %@", igcID)
        query.predicate = predicate
        
        return try CoreDataManager.shared.privateContext.fetch(query).first
    }
    
    ///
    /// Deletes a flight
    ///
    /// - Parameter flight - The flight to delete
    func deleteFlight(_ flight: Flight) throws {
        CoreDataManager.shared.privateContext.delete(flight)
        if CoreDataManager.shared.privateContext.hasChanges || CoreDataManager.shared.viewContext.hasChanges {
            try CoreDataManager.shared.privateContext.save()
            try CoreDataManager.shared.viewContext.save()
        }
    }
    
    ///
    /// Utility function for unit tests
    ///
    func deleteAllFlights() throws {
        Task(priority: .high) {
            do {
                for flight in try await getFlights() {
                    try deleteFlight(flight)
                }
            } catch {
                print("Error deleting all flights")
            }
        }
    }
    
    ///
    /// Updates a stored flights title
    ///
    /// - Parameter forFlight: The flight to update the title for
    /// - Parameter withTitle: The new title to assign
    func updateFlightTitle(forFlight flight: Flight, withTitle newTitle: String) async throws {
        let query = Flight.fetchRequest()
        let predicate = NSPredicate(format: "igcID == %@", flight.igcID!)
        query.predicate = predicate
        let results = try CoreDataManager.shared.privateContext.fetch(query)
        
        if let storedFlight = results.first {
            storedFlight.title = newTitle
            if CoreDataManager.shared.privateContext.hasChanges || CoreDataManager.shared.viewContext.hasChanges {
                try CoreDataManager.shared.privateContext.save()
                try CoreDataManager.shared.viewContext.save()
            }
        }
    }
    
    ///
    /// Imports a flight for the given URL
    ///
    /// - Parameter url: The URL to import from
    /// - Returns true on success, false on failure
    func importAndStoreFlight(forUrl url: URL) async throws -> Bool {
        do {
            var flight = Flight(context: CoreDataManager.shared.privateContext)
            flight.id = UUID()
            flight.title = url.lastPathComponent
            flight.igcID = flight.id!.uuidString
            
            for try await line in url.lines {
                if line.starts(with: "A") {
                    processARecord(record: line, forFlight: &flight)
                    flight.gpsModel = line.subString(from: 1, to: 6)
                }
                if line.starts(with: "B") {
                    processBRecord(record: line, forFlight: &flight)
                }
                if line.starts(with: "H") {
                    try processHRecord(record: line, forFlight: &flight)
                }
            }
                        
            if CoreDataManager.shared.privateContext.hasChanges {
                try CoreDataManager.shared.privateContext.save()
                try CoreDataManager.shared.viewContext.save()
            } else {
                CoreDataManager.shared.privateContext.reset()
                return false
            }
            
            // Post processsing
            let query = Flight.fetchRequest()
            let predicate = NSPredicate(format: "igcID == %@", flight.igcID!)
            query.predicate = predicate
            let results = try CoreDataManager.shared.privateContext.fetch(query)
            if results.count > 0 {
                flight = results.first!
            }
            
            if let frames = (flight.frames?.allObjects as? [FlightFrame])?.sorted(by: { $0.timestamp! < $1.timestamp! }) {
                
                let flightStartDate = frames.first?.timestamp ?? Date.distantPast
                                
                for index in 0...frames.count - 1 {
                    // Detect and update rollover
                    if frames[index].timestamp! < flightStartDate {
                        frames[index].timestamp!.addTimeInterval(86400)
                    }
                    
                    var derrivedVerticalSpeed = 0.0
                    var tsSinceLastUpdate: TimeInterval?
                    
                    if index != 0 {
                        let lastTs = frames[index-1].timestamp!
                        let currentTs = frames[index].timestamp!
                        
                        tsSinceLastUpdate = lastTs.distance(to: currentTs)
                    }
                    
                    if index == 0 {
                        derrivedVerticalSpeed = 0.0
                    } else {
                        let verticalDisplacement = frames[index].baroAltitude - frames[index-1].baroAltitude
                        derrivedVerticalSpeed = verticalDisplacement / tsSinceLastUpdate!
                    }
                    
                    frames[index].derrivedVerticalSpeed = derrivedVerticalSpeed
                }
                
                // Dates / Duration
                guard let first = frames.min(by: { $0.timestamp! < $1.timestamp! }),
                      let last = frames.max(by: { $0.timestamp! < $1.timestamp! }) else {
                    CoreDataManager.shared.privateContext.reset()
                    throw FlightRecorderError.invalidIgcData("Error storing flight \(flight.title ?? "Unknown flight")")
                }
                flight.startDate = first.timestamp!
                flight.endDate = last.timestamp!
                
                let interval = last.timestamp!.timeIntervalSince(first.timestamp!)
                flight.duration = interval.hourMinuteSecond
                
                // Boundaries
                flight.maxLatitude = frames.max(by: { $0.latitude < $1.latitude })?.latitude ?? 0.0
                flight.minLatitude = frames.min(by: { $0.latitude < $1.latitude })?.latitude ?? 0.0
                flight.maxLongitude = frames.max(by: { $0.longitude < $1.longitude })?.longitude ?? 0.0
                flight.minLongitude = frames.min(by: { $0.longitude < $1.longitude })?.longitude ?? 0.0
                
                // Launch / Land
                flight.launchLatitude = first.latitude
                flight.launchLongitude = first.longitude
                flight.landLatitude = first.latitude
                flight.landLongitude = first.longitude
            }
            
            if CoreDataManager.shared.privateContext.hasChanges {
                try CoreDataManager.shared.privateContext.save()
                try CoreDataManager.shared.viewContext.save()
            } else {
                CoreDataManager.shared.privateContext.reset()
                return false
            }
            
            return true
            
        } catch {
            CoreDataManager.shared.privateContext.reset()
            return false
        }
    }
    
    ///
    /// Exports a .IGC file
    ///
    /// - Parameter flightToExport: The flight to be exported
    /// - Returns an IGC file for the selected flight
    func exportFlight(flightToExport: Flight) async throws -> IgcFile? {
        
        let flight = try await getFlight(withIgcId: flightToExport.igcID!)
        guard flight != nil else { throw CdError.noRecordsFound("No flight found to export") }
        
        if let frames = flight!.frames?.allObjects as? [FlightFrame] {
            
            var textToExport = ""
            
            // AXXXX - Flight ID
            textToExport = "ABCXXX" + flightToExport.igcID!
            textToExport.addNewLine()
            
            // HFFXA - Fix precision
            if flightToExport.gpsPrecision != 0 {
                textToExport = "HFFXA:" + String(format: "%.1f", flightToExport.gpsPrecision)
                textToExport.addNewLine()
            }
            
            // HFDTE - Flight Date
            let dateValue = Calendar.current.dateComponents([.day, .month, .year], from: flightToExport.startDate!)
            textToExport += "HFDTE:"
            textToExport += String(format: "%i", dateValue.day ?? 0)
            textToExport += String(format: "%i", dateValue.month ?? 0)
            textToExport += String(format: "%i", dateValue.year ?? 0)
            textToExport.addNewLine()
            
            // HFPLT - Pilot
            if flightToExport.pilot != nil && !flightToExport.pilot!.isEmpty {
                textToExport += "HFPLTPILOTINCHARGE:"
                textToExport += flightToExport.pilot!
                textToExport.addNewLine()
            }
            
            // HFCM2 - Passenger
            if flightToExport.copilot != nil && !flightToExport.copilot!.isEmpty {
                textToExport += "HFCM2CREW2:"
                textToExport += flightToExport.copilot!
                textToExport.addNewLine()
            }
            
            // HFGTY - GliderType
            if flightToExport.gliderName != nil && !flightToExport.gliderName!.isEmpty {
                textToExport += "HFGTYGLIDERTYPE:"
                textToExport += flightToExport.gliderName!
                textToExport.addNewLine()
            }
            
            // HFGID - Glider ID
            if flightToExport.gliderRegistration != nil && !flightToExport.gliderRegistration!.isEmpty {
                textToExport += "HFGIDGLIDERID:"
                textToExport += flightToExport.gliderRegistration!
                textToExport.addNewLine()
            }
            
            // HFDTM - GPS Datum
            if flightToExport.gpsDatum != nil && !flightToExport.gpsDatum!.isEmpty {
                textToExport += "HFDTM:"
                textToExport += flightToExport.gpsDatum!
                textToExport.addNewLine()
            }
            
            // HFRFW - Vario Firmware
            if flightToExport.varioFirmwareVer != nil && !flightToExport.varioFirmwareVer!.isEmpty {
                textToExport += "HFRFWFIRMWAREVERSION:"
                textToExport += flightToExport.varioFirmwareVer!
                textToExport.addNewLine()
            }
            
            // HFRHW - Vario Hardware
            if flightToExport.varioHardwareVer != nil && !flightToExport.varioHardwareVer!.isEmpty {
                textToExport += "HFRHWHARDWAREVERSION:"
                textToExport += flightToExport.varioHardwareVer!
                textToExport.addNewLine()
            }
            
            // HFFTY - Flight Type
            if flightToExport.type != nil && !flightToExport.type!.isEmpty {
                textToExport += "HFFTYFRTYPE:"
                textToExport += flightToExport.type!
                textToExport.addNewLine()
            }
            
            // HFGPS - GPS Model
            if flightToExport.gpsModel != nil && !flightToExport.gpsModel!.isEmpty {
                textToExport += "HFGPSRECEIVER:"
                textToExport += flightToExport.gpsModel!
                textToExport.addNewLine()
            }
            
            // HFPRS - Pressure Sensor
            if flightToExport.pressureSensor != nil && !flightToExport.pressureSensor!.isEmpty {
                textToExport += "HFPRSPRESSALTSENSOR:"
                textToExport += flightToExport.pressureSensor!
                textToExport.addNewLine()
            }
            
            // HFCID - Fin Number
            if flightToExport.finNumber != nil && !flightToExport.finNumber!.isEmpty {
                textToExport += "HFCIDCOMPETITIONID:"
                textToExport += String(describing: flightToExport.finNumber)
                textToExport.addNewLine()
            }
            
            // HFCCL - Free Text
            if flightToExport.freeText != nil && !flightToExport.freeText!.isEmpty {
                textToExport += "HFCCL"
                textToExport += flightToExport.freeText!
                textToExport.addNewLine()
            }
            
            for frame in frames.sorted(by: { $0.timestamp! < $1.timestamp! }) {
                // Date
                let dateValue = Calendar.current.dateComponents([.hour, .minute, .second], from: frame.timestamp!)
                
                textToExport += "B"
                textToExport += String(dateValue.hour!)
                textToExport += String(dateValue.minute!)
                textToExport += String(dateValue.second!)
                
                // Lat / Lng
                let dms = CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude)
                textToExport += dms.coordinateToDMS()
                
                // Baro Alt
                textToExport += "A"
                textToExport += frame.getBaroAltitudeForPrinting()
                
                // GPS Alt
                textToExport += frame.getGpsAltitudeForPrinting()
                textToExport.addNewLine()
            }
            
            return IgcFile(initialText: textToExport)
        } else {
            throw CdError.invalidState("Failed to export file for flight \(flight!.title ?? "Unknown Flight")")
        }
    }
    
    ///
    /// Processes an A record for an imported flight
    ///
    /// - Parameter record: The record to process
    /// - Parameter flight (inout): The flight to assign the record to
    private func processARecord(record line: String, forFlight flight: inout Flight) {
        // Flight ID
        flight.gpsModel = line.subString(from: 1, to: 6)
    }
    
    ///
    /// Processes a B record for an imported flight
    ///
    /// - Parameter record: The record to process
    /// - Parameter flight (inout): The flight to assign the record to
    private func processBRecord(record line: String, forFlight flight: inout Flight) {
        
        var dateComponents = DateComponents()
        dateComponents.year = FlightRecorder.flightDate.get(.year)
        dateComponents.month = FlightRecorder.flightDate.get(.month)
        dateComponents.day = FlightRecorder.flightDate.get(.day)
        dateComponents.hour = Int(line[line.index(line.startIndex, offsetBy: 1)...line.index(line.startIndex, offsetBy: 3)])
        dateComponents.hour = Int(line.subString(from: 1, to: 3).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.minute = Int(line.subString(from: 3, to: 5).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.second = Int(line.subString(from: 5, to: 7).trimmingCharacters(in: .whitespacesAndNewlines))
        let frameTs = Calendar.current.date(from: dateComponents)!
        
        let latDegrees = abs(Double(line.subString(from: 7, to: 9))!)
        let latMinutes = abs(Double(line.subString(from: 9, to: 11))! / 60)
        let latSecondsWhole = abs(Double(line.subString(from: 11, to: 14))!) / 1000
        let latSeconds = (latSecondsWhole * 60) / 3600
        let latDirection = line.subString(from: 14, to: 15)
        let latitude = (latDegrees + latMinutes + latSeconds) * (latDirection == "S" ? -1 : 1)
        
        let longDegrees = abs(Double(line.subString(from: 15, to: 18))!)
        let longMinutes = abs(Double(line.subString(from: 18, to: 20))! / 60)
        let longSeocndsWhole = abs(Double(line.subString(from: 20, to: 23))!) / 1000
        let longSeconds = (longSeocndsWhole * 60) / 3600
        let longDirection = line.subString(from: 23, to: 24)
        let longitude = (longDegrees + longMinutes + longSeconds) * (longDirection == "W" ? -1 : 1)
        
        let baroAlt = Double(line.subString(from: 25, to: 30))!
        let gpsAlt = Double(line.subString(from: 30, to: 35))!
        
        let frame = FlightFrame(context: CoreDataManager.shared.privateContext)
        
        frame.id = UUID()
        frame.timestamp = frameTs
        frame.baroAltitude = baroAlt
        frame.gpsAltitude = gpsAlt
        frame.latitude = latitude
        frame.longitude = longitude
        frame.flight = flight
        frame.flightID = flight.igcID
    }
    
    ///
    /// Processes an H record for a flight
    ///
    /// - Parameter record: The record to process
    /// - Parameter flight (inout): The flight to assign the record to
    private func processHRecord(record line: String, forFlight flight: inout Flight) throws {
        
        // H Record
        switch line.subString(from: 0, to: 5) {
            
            // Flight Date
        case HRecord.HFDTE.rawValue:
            let regex = try Regex("[0-9]{6}")
            if let match = line.firstMatch(of: regex) {
                let date = String(line[match.range])
                
                var dateComponents = DateComponents()
                dateComponents.day = Int(date.subString(from: 1, to: 2))
                dateComponents.month = Int(date.subString(from: 2, to: 4))
                dateComponents.year = (Int(date.subString(from: 4, to: 6)) ?? 0 + 2000)
                FlightRecorder.flightDate = Calendar.current.date(from: dateComponents)!
            } else {
                throw FlightRecorderError.invalidIgcData("Corrupt HFDTE record")
            }
            break
            
            // Fix Accuracy
        case HRecord.HFFXA.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.gpsPrecision = Double(line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
            } else {
                flight.gpsPrecision = Double(line.subString(from: 5, to: line.count)) ?? 0.0
            }
            break
            
            // Pilot
        case HRecord.HFPLT.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.pilot = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.pilot = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Copilot
        case HRecord.HFCM2.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.copilot = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.copilot = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Glider Type
        case HRecord.HFGTY.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.gliderName = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.gliderName = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Glider registration
        case HRecord.HFGID.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.gliderRegistration = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.gliderRegistration = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // GPS datum
        case HRecord.HFDTM.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.gpsDatum = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.gpsDatum = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Firmware
        case HRecord.HFRFW.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.varioFirmwareVer = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.varioFirmwareVer = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Hardware
        case HRecord.HFRHW.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.varioHardwareVer = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.varioHardwareVer = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Flight Type
        case HRecord.HFFTY.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.type = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.type = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // GPS Model
        case HRecord.HFGPS.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.gpsModel = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.gpsModel = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Pressure Sensor
        case HRecord.HFPRS.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.pressureSensor = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.pressureSensor = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Fin number / Free text
        case HRecord.HFCID.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.finNumber = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.finNumber = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Glider description
        case HRecord.HFCCL.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.freeText = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.freeText = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
            // Flight Site
        case HRecord.HFSIT.rawValue:
            if let index = line.firstIndex(of: ":") {
                flight.location = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                flight.location = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            break
            
        default:
            return
        }
    }
    
}
