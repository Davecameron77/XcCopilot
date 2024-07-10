//
//  FlightRecorder.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-30.
//

import CoreData
import CoreLocation
import CoreMotion
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WeatherKit

final class FlightRecorder: FlightRecorderService {
    var flight: Flight
    let container: ModelContainer
    
    init() throws {
        container = try ModelContainer(for: Flight.self)
        flight = Flight()
    }
    
    init(useInMemoryStore: Bool = false) throws {
        let configuration = ModelConfiguration(
            for: Flight.self,
            isStoredInMemoryOnly: useInMemoryStore
        )
        container = try ModelContainer(
            for: Flight.self,
            configurations: configuration
        )
        flight = Flight()
    }
}

// In Flight
extension FlightRecorder {
    
    ///
    /// Enables takeoff detection and passes a reference of the flight to record
    ///
    /// - Parameter flight - The flight to store frames in
    func armForFlight() {
        flight = Flight()
        flight.igcID = flight.id.subString(from: 0, to: 8)
    }
    
    ///
    /// Stores a frame recorded by the flight computer
    ///
    /// - Parameter frame - The frame to store
    @MainActor func storeFrame(
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalVelocity: Double
    ) throws {
        
        let frame = FlightFrame(
            acceleration: acceleration,
            gravity: gravity,
            gpsAltitude: gpsAltitude,
            gpsCourse: gpsCourse,
            gpsCoords: gpsCoords,
            baroAltitude: baroAltitude,
            verticalVelocity: verticalVelocity
        )
        
        flight.addFrame(frame)
        
        let context = container.mainContext
        try context.save()
    }
    
    ///
    /// Ends a flight, calculating metadata
    ///
    @MainActor func endFlight(withWeather weather: Weather?) throws {
        
        if weather != nil {
            flight.addWeather(weather!)
        }
        
        if let firstFrame = flight.frames.min(by: { $0.timestamp < $1.timestamp }),
           let lastFrame = flight.frames.max(by: { $0.timestamp < $1.timestamp }) {
            flight.flightStartDate = firstFrame.timestamp
            flight.flightEndDate = lastFrame.timestamp
            flight.launchLatitude = firstFrame.latitude
            flight.launchLongitude = firstFrame.longitude
            flight.landLatitude = firstFrame.latitude
            flight.landLongitude = firstFrame.longitude
            flight.varioHardwareVer = "iPhone"
            flight.varioFirmwareVer = ""
            flight.gpsModel = "iPhone"
            flight.flightTitle = "Flight: \(flight.flightStartDate!.formatted(.dateTime.day().month().year()))"
            
            let interval = lastFrame.timestamp.timeIntervalSince(firstFrame.timestamp)
            flight.flightDuration = interval.hourMinuteSecond
            
            let context = container.mainContext
            try context.save()
        }
    }
}

// Logbook
extension FlightRecorder {
    ///
    /// Returns a list of all flights
    ///
    func getFlights() async throws -> [Flight] {
        
        let task = Task(priority: .high) {
            let result = try await readFlights()
            return result
        }
        return try await task.result.get()
        
    }
    
    ///
    /// Updates a stored flights title
    ///
    /// - Parameter forFlight: The flight to update the title for
    /// - Parameter withTitle: The new title to assign
    @MainActor func updateFlightTitle(forFlight flight: Flight, withTitle title: String) throws {
        
        let id = flight.id
        let predicate = #Predicate<Flight> { $0.id == id }
        let fetchDescriptor = FetchDescriptor<Flight>(predicate: predicate)
        
        let context = container.mainContext
        let flight = try context.fetch(fetchDescriptor)
        
        if !flight.isEmpty {
            flight.first?.flightTitle = title
            try context.save()
        }
    }
    
    ///
    /// Deletes a flight
    ///
    /// - Parameter flight - The flight to delete
    func deleteFlight(_ flight: Flight) throws {
        
        Task(priority: .high) {
            try await removeFlight(flight)
        }
        
    }
    
    ///
    /// Imports a .IGC file
    ///
    /// - Parameter forUrl: The URL from which the flight shall be imported
    @MainActor func importFlight(forUrl url: URL) async throws {
        
        let context = await container.mainContext
        
        var flightDate: Date = Date.now
        let flight = Flight()
        flight.flightTitle = "\(url.lastPathComponent)"
        
        context.insert(flight)
        try context.save()
        
        
        for try await line in url.lines {
            
            if line.starts(with: "A") {
                // Flight ID
                flight.gpsModel = line.subString(from: 1, to: 3)
                flight.igcID = line.subString(from: 1, to: line.count)
            } else if line.starts(with: "H") {
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
                        flightDate = Calendar.current.date(from: dateComponents)!
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
                        flight.flightPilot = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        flight.flightPilot = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    break
                    
                    // Copilot
                case HRecord.HFCM2.rawValue:
                    if let index = line.firstIndex(of: ":") {
                        flight.flightCopilot = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        flight.flightCopilot = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
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
                        flight.flightType = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        flight.flightType = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
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
                        flight.flightFreeText = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        flight.flightFreeText = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    break
                    
                    // Flight Site
                case HRecord.HFSIT.rawValue:
                    if let index = line.firstIndex(of: ":") {
                        flight.flightLocation = line[line.index(after: index)...].description.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        flight.flightLocation = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    break
                    
                default:
                    continue
                }
                
            } else if line.starts(with: "B") {
                
                var dateComponents = DateComponents()
                dateComponents.year = flightDate.get(.year)
                dateComponents.month = flightDate.get(.month)
                dateComponents.day = flightDate.get(.day)
                dateComponents.hour = Int(line[line.index(line.startIndex, offsetBy: 1)...line.index(line.startIndex, offsetBy: 3)])
                dateComponents.hour = Int(line.subString(from: 1, to: 3).trimmingCharacters(in: .whitespacesAndNewlines))
                dateComponents.minute = Int(line.subString(from: 3, to: 5).trimmingCharacters(in: .whitespacesAndNewlines))
                dateComponents.second = Int(line.subString(from: 5, to: 7).trimmingCharacters(in: .whitespacesAndNewlines))
                
                // Detect rollover
                var frameTs = Calendar.current.date(from: dateComponents)!
                
                if flight.frames.count > 0 {
                    if flight.frames.last!.timestamp > frameTs {
                        frameTs.addTimeInterval(86400)
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
                let frame = FlightFrame()
                
                frame.timestamp = frameTs
                frame.accelerationX = 0
                frame.accelerationY = 0
                frame.accelerationZ = 0
                frame.gravityX = 0
                frame.gravityY = 0
                frame.gravityZ = 0
                frame.currentGPSAltitude = gpsAlt
                frame.currentGPSCourse = 0
                frame.latitude = latitude
                frame.longitude = longitude
                frame.currentBaroAltitude = baroAlt
                frame.currentVerticalVelocity = 0
                
                flight.addFrame(frame)

            }
            
        }
        
        let frames = flight.frames
        guard let first = frames.min(by: { $0.timestamp < $1.timestamp }),
              let last = frames.max(by: { $0.timestamp < $1.timestamp }) else {
            throw DataError.invalidData("Invalid flight dates found in file")
        }
        
        // Duration
        flight.flightStartDate = first.timestamp
        flight.flightEndDate = last.timestamp
        
        let duration = flight.flightStartDate!.distance(to: flight.flightEndDate!)
        let hour = String(format: "%02d", duration.hour)
        let minute = String(format: "%02d", duration.minute)
        let second = String(format: "%02d", duration.second)
        flight.flightDuration = "\(hour):\(minute):\(second)"
        
        // Launch / Land
        flight.launchLatitude = first.latitude
        flight.launchLongitude = first.longitude
        flight.landLatitude = last.latitude
        flight.landLongitude = last.longitude
        
        #if !DEBUG
        flight.flightTitle = "Imported Flight: \(flightDate.formatted(.dateTime.year().month().day()))"
        #endif
        
        try context.save()
        
        #if DEBUG
        print("Imported a flight: \(flight.flightTitle)")
        #endif
    }
    
    ///
    /// Exports a .IGC file
    ///
    /// - Parameter flightToExport: The flight to be xported
    func exportFlight(flightToExport: Flight) async throws -> IgcFile {
        
        var textToExport = ""
        
        // AXXXX - Flight ID
        textToExport = "ABCXXX" + flightToExport.igcID
        textToExport.addNewLine()
        
        // HFFXA - Fix precision
        if flightToExport.gpsPrecision != 0 {
            textToExport = "HFFXA:" + String(describing: flightToExport.gpsPrecision)
            textToExport.addNewLine()
        }
        
        // HFDTE - Flight Date
        let dateValue = Calendar.current.dateComponents([.day, .month, .year], from: flightToExport.flightStartDate!)
        textToExport += "HFDTE:"
        textToExport += String(describing: dateValue.day)
        textToExport += String(describing: dateValue.month)
        textToExport += String(describing: dateValue.year)
        textToExport.addNewLine()
        
        // HFPLT - Pilot
        textToExport += "HFPLTPILOTINCHARGE:"
        textToExport += String(describing: flightToExport.flightPilot)
        textToExport.addNewLine()
        
        // HFCM2 - Passenger
        textToExport += "HFCM2CREW2:"
        textToExport += String(describing: flightToExport.flightCopilot)
        textToExport.addNewLine()
        
        // HFGTY - GliderType
        textToExport += "HFGTYGLIDERTYPE:"
        textToExport += String(describing: flightToExport.gliderName)
        textToExport.addNewLine()
        
        // HFGID - Glider ID
        textToExport += "HFGIDGLIDERID:"
        textToExport += String(describing: flightToExport.gliderRegistration)
        textToExport.addNewLine()
        
        // HFDTM - GPS Datum
        textToExport += "HFDTM:"
        textToExport += String(describing: flightToExport.gpsDatum)
        textToExport.addNewLine()
        
        // HFRFW - Vario Firmware
        textToExport += "HFRFWFIRMWAREVERSION:"
        textToExport += String(describing: flightToExport.varioFirmwareVer)
        textToExport.addNewLine()
        
        // HFRHW - Vario Hardware
        textToExport += "HFRHWHARDWAREVERSION:"
        textToExport += String(describing: flightToExport.varioHardwareVer)
        textToExport.addNewLine()
        
        // HFFTY - Flight Type
        textToExport += "HFFTYFRTYPE:"
        textToExport += String(describing: flightToExport.flightType)
        textToExport.addNewLine()
        
        // HFGPS - GPS Model
        textToExport += "HFGPSRECEIVER:"
        textToExport += String(describing: flightToExport.gpsModel)
        textToExport.addNewLine()
        
        // HFPRS - Pressure Sensor
        textToExport += "HFPRSPRESSALTSENSOR:"
        textToExport += String(describing: flightToExport.pressureSensor)
        textToExport.addNewLine()
        
        // HFCID - Fin Number
        textToExport += "HFCIDCOMPETITIONID:"
        textToExport += String(describing: flightToExport.finNumber)
        textToExport.addNewLine()
        
        // HFCCL - Free Text
        textToExport += "HFCCL"
        textToExport += String(describing: flightToExport.flightFreeText)
        textToExport.addNewLine()
        
        for frame in flightToExport.frames {
            // Date
            let dateValue = Calendar.current.dateComponents([.hour, .minute, .second], from: frame.timestamp)
            
            textToExport += "B"
            textToExport += String(format: "%i", dateValue.hour!)
            textToExport += String(format: "%i", dateValue.minute!)
            textToExport += String(format: "%i", dateValue.second!)
            
            // Lat / Lng
            let dms = CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude)
            textToExport += dms.coordinateToDMS()
            #warning("Broken casting, export prints decimal places")
            // Baro Alt
            textToExport += "A"
            textToExport += String(format: "%i", frame.currentBaroAltitude.rounded(toPlaces: 0))
            
            // GPS Alt
            textToExport += String(format: "%i", frame.currentGPSAltitude)
            textToExport.addNewLine()
        }
        
        return IgcFile(initialText: textToExport)
    }
    
    @MainActor private func insert(_ flight: Flight) throws {
        let context = container.mainContext
        context.insert(flight)
        try context.save()
    }
    
    @MainActor private func newFlight() throws -> Flight {
        let context = container.mainContext
        let flight = Flight()
        context.insert(flight)
        try context.save()
        return flight
    }
    
    @MainActor private func readFlights() throws -> [Flight] {
        
        let fetchDescriptor = FetchDescriptor<Flight>(predicate: nil)
        let context = container.mainContext
        let flights = try context.fetch(fetchDescriptor)
        return flights
        
    }
    
    @MainActor private func readFlight(withId id: String) throws -> Flight? {
        
        let predicate = #Predicate<Flight> { $0.id == id }
        let fetchDescriptor = FetchDescriptor<Flight>(predicate: predicate)
        
        let context = container.mainContext
        let results = try context.fetch(fetchDescriptor)
        return results.first
        
    }
    
    @MainActor private func removeFlight(_ flight: Flight) throws {
        
        let context = container.mainContext
        context.delete(flight)
        try context.save()
        
    }
}
