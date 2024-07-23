//
//  FlightRecorder.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-30.
//

import CoreData
import CoreLocation
import CoreMotion
import SwiftUI
import UniformTypeIdentifiers
import WeatherKit

actor FlightRecorder {
    
    var flight: Flight?
    static var flightDate: Date = Date.now
    let container: NSPersistentContainer
    let context: NSManagedObjectContext
    
    init() {
        container = NSPersistentContainer(name: "XCCopilot")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error)")
            }
        }
        context = container.viewContext
    }

    ///
    /// Enables takeoff detection and passes a reference of the flight to record
    ///
    /// - Parameter flight - The flight to store frames in
    func armForFlight() throws {
        flight = try createFlight()
    }
    
    ///
    /// Stores a frame recorded by the flight computer
    ///
    /// - Parameter frame - The frame to store
    func storeFrame(
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalVelocity: Double
    ) throws {
        guard flight != nil else { throw FlightRecorderError.invalidState("No flight assigned for recording") }
        
        let frame = try createFrame()
        frame.assignVars(
            acceleration: acceleration,
            gravity: gravity,
            gpsAltitude: gpsAltitude,
            gpsCourse: gpsCourse,
            gpsCoords: gpsCoords,
            baroAltitude: baroAltitude,
            verticalSpeed: verticalVelocity,
            flightId: flight!.igcID!,
            flight: flight!
        )
        
        try addFrame(frame)
    }
    
    ///
    /// Ends a flight, calculating metadata
    ///
    func endFlight(withWeather weather: Weather?) async throws {
        guard flight != nil else { throw FlightRecorderError.invalidState("No flight assigned for recording") }
        
        try concludeFlight(flight!, andWeather: weather)
    }
    
}

// Logbook
extension FlightRecorder {
    ///
    /// Returns a list of all flights
    ///
    func getFlights() throws -> [Flight] {
        
        let request = Flight.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        return try context.fetch(request)
    }
    
    ///
    /// Returns flights that took off within the given region
    ///
    func getFlightsAroundRegion(_ region: CLLocationCoordinate2D) throws -> [Flight] {
        
        let request = Flight.fetchRequest()
        let maxLat = region.latitude + 1
        let minLat = region.latitude - 1
        let maxLong = region.longitude + 1
        let minLong = region.longitude - 1
        
        let predicate = NSPredicate(format: "launchLatitude >= %f AND launchLatitude <= %f AND launchLongitude >= %f AND launchLongitude <= %f", minLat, maxLat, minLong, maxLong)
        request.predicate = predicate
        
        let result = try context.fetch(request)
        return result
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
        let results = try context.fetch(query)
        if let storedFlight = results.first {
            try context.save()
            storedFlight.title = newTitle
        }
        
    }
    
    ///
    /// Deletes a flight
    ///
    /// - Parameter flight - The flight to delete
    func deleteFlight(_ flight: Flight) throws {
        context.delete(flight)
        try context.save()
    }
    
    ///
    /// Imports a .IGC file
    ///
    /// - Parameter forUrl: The URL from which the flight shall be imported
    func importFlight(forUrl url: URL) async throws {
        
        do {
            
            var flight = try createFlight(withTitle: url.lastPathComponent)
            flight.imported = true
            
            for try await line in url.lines {
                
                if line.starts(with: "A") {
                    processARecord(record: line, forFlight: &flight)
                }
                else if line.starts(with: "B") {
                    try processBRecord(record: line, forFlight: flight)
                }
                else if line.starts(with: "H") {
                    try processHRecord(record: line, forFlight: &flight)
                }
            }
                        
            try concludeFlight(flight, andWeather: nil)
            
//            try context.save()
            
            #if DEBUG
            print("Imported a flight: \(flight.title!)")
            #endif
            
        } catch {
            try deleteFlight(flight!)
            print("Import Error: \(error)")
            throw error
        }
    }
    
    ///
    /// Exports a .IGC file
    ///
    /// - Parameter flightToExport: The flight to be xported
    func exportFlight(flightToExport: Flight) async throws -> IgcFile? {
        
        let flight = try getFlight(withIgcId: flightToExport.igcID!)
        
        if let frames = flight.frames?.allObjects as? [FlightFrame] {
            
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
            throw CdError.invalidState("Failed to export file for flight \(flight.title ?? "Unknown Flight")")
        }
    }
}

// CoreData functions
extension FlightRecorder {
    
    private func createFlight() throws -> Flight {
        let flight = Flight(context: context)
        flight.id = UUID()
        flight.igcID = flight.id?.uuidString
        return flight
    }
    
    private func createFlight(withTitle title: String) throws -> Flight {
        let flight = Flight(context: context)
        flight.id = UUID()
        flight.igcID = flight.id?.uuidString
        flight.title = title
        context.insert(flight)
        try context.save()
        return flight
    }
    
    private func createFrame() throws -> FlightFrame {
        let frame = FlightFrame(context: context)
        try context.save()
        return frame
    }
    
    private func concludeFlight(_ flight: Flight, andWeather weather: Weather?) throws {
        if let frames = flight.frames?.allObjects as? [FlightFrame] {
            guard let first = frames.min(by: { $0.timestamp! < $1.timestamp! }),
                  let last = frames.max(by: { $0.timestamp! < $1.timestamp! }) else {
                throw DataError.invalidData("Invalid flight dates found in file")
            }
            
            // Duration
            flight.startDate = first.timestamp
            flight.endDate = last.timestamp
            
            let duration = flight.startDate!.distance(to: flight.endDate!)
            let hour = String(format: "%02d", duration.hour)
            let minute = String(format: "%02d", duration.minute)
            let second = String(format: "%02d", duration.second)
            flight.duration = "\(hour):\(minute):\(second)"
            
            let interval = last.timestamp!.timeIntervalSince(first.timestamp!)
            flight.duration = interval.hourMinuteSecond
            
            // Launch / Land
            flight.launchLatitude = first.latitude
            flight.launchLongitude = first.longitude
            flight.landLatitude = last.latitude
            flight.landLongitude = last.longitude
            
            // Derrived vertical speed
            let sortedFrames = frames.sorted(by: { $0.timestamp! < $1.timestamp! })
            
            for index in 0...sortedFrames.count - 1 {
                
                var derrivedVerticalSpeed = 0.0
                
                if index == 0 {
                    derrivedVerticalSpeed = 0.0
                } else if index == 1 {
                    derrivedVerticalSpeed = sortedFrames[index].baroAltitude - sortedFrames[index-1].baroAltitude
                } else if index == 2 {
                    var delta = 0.0
                    delta += sortedFrames[index].baroAltitude - sortedFrames[index-1].baroAltitude
                    delta += sortedFrames[index-1].baroAltitude - sortedFrames[index-2].baroAltitude
                 
                    derrivedVerticalSpeed = delta / 2.0
                } else if index == 3 {
                    var delta = 0.0
                    delta += sortedFrames[index].baroAltitude - sortedFrames[index-1].baroAltitude
                    delta += sortedFrames[index-1].baroAltitude - sortedFrames[index-2].baroAltitude
                    delta += sortedFrames[index-2].baroAltitude - sortedFrames[index-3].baroAltitude
                                     
                    derrivedVerticalSpeed = delta / 3.0
                } else {
                    var delta = 0.0
                    delta += sortedFrames[index].baroAltitude - sortedFrames[index-1].baroAltitude
                    delta += sortedFrames[index-1].baroAltitude - sortedFrames[index-2].baroAltitude
                    delta += sortedFrames[index-2].baroAltitude - sortedFrames[index-3].baroAltitude
                    delta += sortedFrames[index-3].baroAltitude - sortedFrames[index-4].baroAltitude
                                     
                    derrivedVerticalSpeed = delta / 4.0
                }
                
                sortedFrames[index].derrivedVerticalSpeed = derrivedVerticalSpeed
            }
            
            // Boundaries
            flight.maxLatitude = frames.max(by: { $0.latitude < $1.latitude })?.latitude ?? 0.0
            flight.minLatitude = frames.min(by: { $0.latitude < $1.latitude })?.latitude ?? 0.0
            flight.maxLongitude = frames.max(by: { $0.longitude < $1.longitude })?.longitude ?? 0.0
            flight.minLongitude = frames.min(by: { $0.longitude < $1.longitude })?.longitude ?? 0.0
            
            // Meta
            flight.varioHardwareVer = "iPhone"
            flight.varioFirmwareVer = ""
            flight.gpsModel = "iPhone"
            #if !DEBUG
            flight.flightTitle = "Imported Flight: \(flightDate.formatted(.dateTime.year().month().day()))"
            #endif
            
            // Weather
            if weather != nil {
                flight.addWeather(weather: weather!)
            }
            
            try context.save()
        }
    }
       
    private func getFlight(withIgcId igcId: String) throws -> Flight {
        let request = Flight.fetchRequest()
        request.predicate = NSPredicate(format: "igcID == %@", igcId)
        let results = try context.fetch(request)
        
        if results.isEmpty {
            throw CdError.noRecordsFound("No stored flight found")
        } else {
            return results.first!
        }
    }
    
    private func createFrame(forFlight flight: Flight) throws -> FlightFrame {
        let frame = FlightFrame(context: context)
        frame.id = UUID()
        frame.flight = flight
        frame.flightID = flight.igcID
        
        return frame
    }
    
    private func addFrame(_ frame: FlightFrame) throws {
        context.insert(frame)
        try context.save()
    }
    
    private func processARecord(record line: String, forFlight flight: inout Flight) {
        // Flight ID
        flight.gpsModel = line.subString(from: 1, to: 3)
    }
    
    private func processBRecord(record line: String, forFlight flight: Flight) throws {
        var dateComponents = DateComponents()
        dateComponents.year = FlightRecorder.flightDate.get(.year)
        dateComponents.month = FlightRecorder.flightDate.get(.month)
        dateComponents.day = FlightRecorder.flightDate.get(.day)
        dateComponents.hour = Int(line[line.index(line.startIndex, offsetBy: 1)...line.index(line.startIndex, offsetBy: 3)])
        dateComponents.hour = Int(line.subString(from: 1, to: 3).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.minute = Int(line.subString(from: 3, to: 5).trimmingCharacters(in: .whitespacesAndNewlines))
        dateComponents.second = Int(line.subString(from: 5, to: 7).trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Detect rollover
        var frameTs = Calendar.current.date(from: dateComponents)!
        if let frames = flight.frames?.allObjects as? [FlightFrame] {
            if frames.count > 0 {
                if frames.last!.timestamp! > frameTs {
                    frameTs.addTimeInterval(86400)
                }
            }
        }
        
        let latDegrees = abs(Double(line.subString(from: 7, to: 9))!)
        let latMinutes = abs(Double(line.subString(from: 9, to: 11))! / 60)
        let latSecondsWhole = abs(Double(line.subString(from: 11, to: 14))!) / 1000
        let latSeconds = (latSecondsWhole * 60) / 3600
        let latDirection = line.subString(from: 14, to: 15)
        var latitude = latDegrees + latMinutes + latSeconds
        if latDirection == "S" {
            latitude *= -1
        }
        
        let longDegrees = abs(Double(line.subString(from: 15, to: 18))!)
        let longMinutes = abs(Double(line.subString(from: 18, to: 20))! / 60)
        let longSeocndsWhole = abs(Double(line.subString(from: 20, to: 23))!) / 1000
        let longSeconds = (longSeocndsWhole * 60) / 3600
        let longDirection = line.subString(from: 23, to: 24)
        var longitude = longDegrees + longMinutes + longSeconds
        if longDirection == "W" {
            longitude *= -1
        }
        
        let baroAlt = Double(line.subString(from: 25, to: 29))!
        let gpsAlt = Double(line.subString(from: 30, to: 35))!
        
        let frame = try createFrame(forFlight: flight)
        frame.assignVars(
            acceleration: CMAcceleration(x: 0, y: 0, z: 0),
            gravity: CMAcceleration(x: 0, y: 0, z: 0),
            gpsAltitude: gpsAlt,
            gpsCourse: 0,
            gpsCoords: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            baroAltitude: baroAlt,
            verticalSpeed: 0,
            flightId: flight.igcID!,
            flight: flight
        )
        frame.timestamp = frameTs
        
        try addFrame(frame)
    }
    
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
                dateComponents.year = (Int(date.subString(from: 4, to: 6))! + 2000)
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

