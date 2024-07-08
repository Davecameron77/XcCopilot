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
    let container = NSPersistentContainer(name: "XCCopilot")
    let context: NSManagedObjectContext
    
    init() {
        container.loadPersistentStores { storeDescription, error in
            guard error == nil else {
                fatalError("Unresolved error \(error!.localizedDescription)")
            }
        }
        context = container.viewContext
    }

    ///
    /// Enables takeoff detection and passes a reference of the flight to record
    ///
    /// - Parameter flight - The flight to store frames in
    func armForFlight() {
        flight = Flight(context: context)
        flight!.igcID = UUID().uuidString.subString(from: 0, to: 8)
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
        
        let frame = FlightFrame(context: context)
        frame.assignVars(
            acceleration: acceleration,
            gravity: gravity,
            gpsAltitude: gpsAltitude,
            gpsCourse: gpsCourse,
            gpsCoords: gpsCoords,
            baroAltitude: baroAltitude,
            verticalVelocity: verticalVelocity,
            flightId: flight!.igcID!
        )
        
        flight!.addToFrames(frame)
        
        try context.save()
    }
    
    ///
    /// Ends a flight, calculating metadata
    ///
    func endFlight(withWeather weather: Weather?) async throws {
        guard flight != nil else { throw FlightRecorderError.invalidState("No flight assigned for recording") }
        
        if let frames = flight!.frames?.array as? [FlightFrame] {
            if let firstFrame = frames.min(by: { $0.timestamp! < $1.timestamp! }),
               let lastFrame = frames.max(by: { $0.timestamp! < $1.timestamp! }) {
                flight!.flightStartDate = firstFrame.timestamp
                flight!.flightEndDate = lastFrame.timestamp
                flight!.launchLatitude = firstFrame.latitude
                flight!.launchLongitude = firstFrame.longitude
                flight!.landLatitude = firstFrame.latitude
                flight!.landLongitude = firstFrame.longitude
                flight!.varioHardwareVer = "iPhone"
                flight!.varioFirmwareVer = ""
                flight!.gpsModel = "iPhone"
                flight!.flightTitle = "Flight: \(flight?.flightStartDate!.formatted(.dateTime.day().month().year()) ?? "Unknown")"
                
                let interval = lastFrame.timestamp!.timeIntervalSince(firstFrame.timestamp!)
                flight!.flightDuration = interval.hourMinuteSecond
                
                // Save flight / frames
                do {
                    defer {
                        flight = nil
                    }
                    try context.save()
                    
                } catch {
                    throw CdError.recordingFailure("Failed to record flight: \(flight!.flightTitle ?? "Unknown Flight")")
                }
            } else {
                flight = nil
                throw FlightRecorderError.recordingFailure("Failed to record flight: \(flight?.flightTitle ?? "Unknown Flight")")
            }
        }
    }
    
    ///
    /// Returns a list of all flights
    ///
    func getFlights() throws -> [Flight] {
        let request = Flight.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "flightStartDate", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(request)
        } catch {
            throw error
        }
    }
    
    ///
    /// Updates a stored flights title
    ///
    /// - Parameter forFlight: The flight to update the title for
    /// - Parameter withTitle: The new title to assign
    func updateFlightTitle(forFlight flight: Flight, withTitle title: String) async throws {
        flight.flightTitle = title
        try context.save()
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
            var flightDate: Date = Date.now
            let flight = Flight(context: context)
            flight.flightID = UUID()
            flight.flightTitle = "\(url.lastPathComponent)"
            
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
                    
                    if flight.frames!.count > 0 {
                        if let frames = flight.frames?.array as? [FlightFrame] {
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
                    let frame = FlightFrame(context: context)
                    
                    frame.id = UUID()
                    frame.flightID = "fuck" //flight.flightID?.uuidString
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
                    
                    flight.addToFrames(frame)
                }
            }
            
            if let frames = flight.frames!.array as? [FlightFrame] {
                guard let first = frames.min(by: { $0.timestamp! < $1.timestamp! }),
                      let last = frames.max(by: { $0.timestamp! < $1.timestamp! }) else {
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
                
            }
            
            try context.save()
                        
            #if DEBUG
            print("Imported a flight: \(flight.flightTitle!)")
            #endif
        } catch {
            print("Import Error: \(error)")
            throw error
        }
    }
    
    ///
    /// Exports a .IGC file
    ///
    /// - Parameter flightToExport: The flight to be xported
    func exportFlight(flightToExport: Flight) async throws -> IgcFile {
        
        let request = FlightFrame.fetchRequest()
        let predicate = NSPredicate(format: "flightIgcID == %@", flightToExport.igcID ?? "")
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
        
        request.predicate = predicate
        request.sortDescriptors = [sortDescriptor]
        
        if let frames = try? context.fetch(request) {
            
            var textToExport = ""
            
            // AXXXX - Flight ID
            textToExport = "ABCXXX" + flightToExport.igcID!
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
            if flightToExport.flightPilot != nil && !flightToExport.flightPilot!.isEmpty {
                textToExport += "HFPLTPILOTINCHARGE:"
                textToExport += String(describing: flightToExport.flightPilot)
                textToExport.addNewLine()
            }
            
            // HFCM2 - Passenger
            if flightToExport.flightCopilot != nil && !flightToExport.flightCopilot!.isEmpty {
                textToExport += "HFCM2CREW2:"
                textToExport += String(describing: flightToExport.flightCopilot)
                textToExport.addNewLine()
            }
            
            // HFGTY - GliderType
            if flightToExport.gliderName != nil && !flightToExport.gliderName!.isEmpty {
                textToExport += "HFGTYGLIDERTYPE:"
                textToExport += String(describing: flightToExport.gliderName)
                textToExport.addNewLine()
                
            }
            
            // HFGID - Glider ID
            if flightToExport.gliderRegistration != nil && !flightToExport.gliderRegistration!.isEmpty {
                textToExport += "HFGIDGLIDERID:"
                textToExport += String(describing: flightToExport.gliderRegistration)
                textToExport.addNewLine()
            }
            
            // HFDTM - GPS Datum
            textToExport += "HFDTM:"
            textToExport += String(describing: flightToExport.gpsDatum)
            textToExport.addNewLine()
            
            // HFRFW - Vario Firmware
            if flightToExport.varioFirmwareVer != nil && !flightToExport.varioFirmwareVer!.isEmpty {
                textToExport += "HFRFWFIRMWAREVERSION:"
                textToExport += String(describing: flightToExport.varioFirmwareVer)
                textToExport.addNewLine()
            }
            
            // HFRHW - Vario Hardware
            if flightToExport.varioHardwareVer != nil && !flightToExport.varioHardwareVer!.isEmpty {
                textToExport += "HFRHWHARDWAREVERSION:"
                textToExport += String(describing: flightToExport.varioHardwareVer)
                textToExport.addNewLine()
            }
            
            // HFFTY - Flight Type
            if flightToExport.flightType != nil && !flightToExport.flightType!.isEmpty {
                textToExport += "HFFTYFRTYPE:"
                textToExport += String(describing: flightToExport.flightType)
                textToExport.addNewLine()
            }
            
            // HFGPS - GPS Model
            if flightToExport.gpsModel != nil && !flightToExport.gpsModel!.isEmpty {
                textToExport += "HFGPSRECEIVER:"
                textToExport += String(describing: flightToExport.gpsModel)
                textToExport.addNewLine()
            }
            
            // HFPRS - Pressure Sensor
            if flightToExport.pressureSensor != nil && !flightToExport.pressureSensor!.isEmpty {
                textToExport += "HFPRSPRESSALTSENSOR:"
                textToExport += String(describing: flightToExport.pressureSensor)
                textToExport.addNewLine()
            }
            
            // HFCID - Fin Number
            if flightToExport.finNumber != nil && !flightToExport.finNumber!.isEmpty {
                textToExport += "HFCIDCOMPETITIONID:"
                textToExport += String(describing: flightToExport.finNumber)
                textToExport.addNewLine()
            }
            
            // HFCCL - Free Text
            if flightToExport.flightFreeText != nil && !flightToExport.flightFreeText!.isEmpty {
                textToExport += "HFCCL"
                textToExport += String(describing: flightToExport.flightFreeText)
                textToExport.addNewLine()
            }
            
            for frame in frames {
                // Date
                let dateValue = Calendar.current.dateComponents([.hour, .minute, .second], from: frame.timestamp!)
                
                textToExport += "B"
                textToExport += String(dateValue.hour!)
                textToExport += String(dateValue.minute!)
                textToExport += String(dateValue.second!)
                
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
        } else {
            throw CdError.invalidState("Failed to export file for flight \(flight?.flightTitle ?? "Unknown flight")")
        }
    }
}
