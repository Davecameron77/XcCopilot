//
//  FlightRecorder.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-30.
//

import Foundation
import CoreLocation
import SwiftUI
import SwiftData

class FlightRecorder: FlightRecorderService {
    
    ///
    /// Init a new flight
    ///
    init(currentFlight: Flight? = nil) {
        self.currentFlight = currentFlight
    }
    
    var recording: Bool = false
    private var currentFlight: Flight?
    
    ///
    /// Starts recording a new flight
    ///
    func startRecording() {
        recording = true
        currentFlight = .init()
    }
    
    ///
    /// Stops recording a flight and archives it
    ///
    func stopRecording(context: ModelContext) {
        recording = false
        if let flightToArchive = self.currentFlight {
            context.insert(flightToArchive)
        }
    }
    
    ///
    /// Stores a flight frame to the current flight
    ///
    func storeFrame(frame: FlightFrame) {
        if !recording {
            startRecording()
        }
        if currentFlight != nil && currentFlight?.flightFrames != nil {
            currentFlight!.flightFrames.append(frame)
        }
    }
    
    ///
    /// Imports a .IGC file
    ///
    func createFlightToImport(forUrl url: URL) async throws -> Flight? {
        let flight = Flight()
        var flightDate: Date = Date.now
        var frames = [FlightFrame]()
               
        for try await line in url.lines {
            
            if line.starts(with: "A") {
                // Flight ID
                flight.igcID = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                
            } else if line.starts(with: "H") {
                // H Record
                
                if line.starts(with: "HFDTE") {
                    // Flight Date
                    let date = line.subString(from: 5, to: line.count)
                    var dateComponents   = DateComponents()
                    dateComponents.day   = Int(date.subString(from: 1, to: 2))
                    dateComponents.month = Int(date.subString(from: 2, to: 4))
                    dateComponents.year  = (Int(date.subString(from: 4, to: 6))! + 2000)
                    flightDate = Calendar.current.date(from: dateComponents)!
                } else if line.starts(with: "HFFXA") {
                    // Fix Accuracy
                    flight.gpsPrecision = Int(line.subString(from: 5, to: line.count))
                } else if line.starts(with: "HFPLT") {
                    // Pilot
                    flight.flightPilot = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines )
                } else if line.starts(with: "HFCM2") {
                    // Copilot
                    flight.flightCopilot = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFGTY") {
                    // Glider Type
                    flight.gliderName = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFGID") {
                    // Glider registration
                    flight.gliderRegistration = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFDTM") {
                    // GPS datum
                    flight.gpsDatum = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFRFW") {
                    // Firmware
                    flight.varioFirmwareVer = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFRHW") {
                    // Hardware
                    flight.varioHardwareVer = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFFTY") {
                    // Flight Type
                    flight.flightType = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFGPS") {
                    // GPS Model
                    flight.gpsModel = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFPRS") {
                    // Pressure Sensor
                    flight.pressureSensor = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFCID") {
                    // Fin number / Free text
                    flight.finNumber = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFCCL") {
                    // Glider description
                    flight.flightFreeText = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.starts(with: "HFSIT") {
                    // Flight Site
                    flight.flightLocation = line.subString(from: 5, to: line.count).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            
            } else if line.starts(with: "B") {
                
                var dateComponents    = DateComponents()
                dateComponents.year   = flightDate.get(.year)
                dateComponents.month  = flightDate.get(.month)
                dateComponents.day    = flightDate.get(.day)
                dateComponents.hour   = Int(line.subString(from: 1, to: 3).trimmingCharacters(in: .whitespacesAndNewlines))
                dateComponents.minute = Int(line.subString(from: 3, to: 5).trimmingCharacters(in: .whitespacesAndNewlines))
                dateComponents.second = Int(line.subString(from: 5, to: 7).trimmingCharacters(in: .whitespacesAndNewlines))
                
                // Detect rollover
                var frameTs = Calendar.current.date(from: dateComponents)!
                if !frames.isEmpty && frames.last!.timestamp > frameTs {
                    frameTs.addTimeInterval(86400)
                }
                
                let latDegrees        = abs(Double(line.subString(from: 7, to: 9))!)
                let latMinutes        = abs(Double(line.subString(from: 9, to: 11))! / 60)
                let latSeconds        = abs(Double(line.subString(from: 11, to: 14))! / 3600)
                let latDirection      = line.subString(from: 14, to: 15)
                var latitude          = latDegrees + latMinutes + latSeconds
                if latDirection == "S" {
                    latitude *= -1
                }
                
                let longDegrees       = abs(Double(line.subString(from: 15, to: 18))!)
                let longMinutes       = abs(Double(line.subString(from: 18, to: 20))! / 60)
                let longSeconds       = abs(Double(line.subString(from: 20, to: 23))! / 3600)
                let longDirection     = line.subString(from: 23, to: 24)
                var longitude         = longDegrees + longMinutes + longSeconds
                if longDirection == "W" {
                    longitude *= -1
                }
                
                let baroAlt           = Double(line.subString(from: 25, to: 29))!
                let gpsAlt            = Double(line.subString(from: 30, to: 35))!
                
                let frame = FlightFrame(
                    pitchInDegrees: 0,
                    rollInDegrees: 0,
                    yawInDegrees: 0,
                    acceleration: .init(x: 0, y: 0, z: 0),
                    gravity: .init(x: 0, y: 0, z: 0),
                    gpsAltitude: gpsAlt,
                    gpsCourse: 0,
                    gpsCoords: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    baroAltitude: baroAlt,
                    verticalVelocity: 0
                )
                frame.timestamp = frameTs
                frames.append(frame)
            }
        }
        
        guard let first = frames.min(by: { $0.timestamp < $1.timestamp }),
              let last = frames.max(by: { $0.timestamp < $1.timestamp }) else {
            throw DataError.invalidData("Invalid flight dates found inf ile")
        }
        
        // Duration
        flight.flightStartDate = first.timestamp
        flight.flightEndDate = last.timestamp
        
        let duration = flight.flightStartDate.distance(to: flight.flightEndDate)
        let hour = String(format: "%02d", duration.hour)
        let minute = String(format: "%02d", duration.minute)
        let second = String(format: "%02d", duration.second)
        flight.flightDuration = "\(hour):\(minute):\(second)"
        
        // Launch / Land
        flight.launchLatitude = first.latitude
        flight.launchLongitude = first.longitude
        flight.landLatitude = last.latitude
        flight.landLongitude = last.longitude
        
        frames.forEach { frame in
            flight.flightFrames.append(frame)
        }
//        flight.flightFrames = frames
        
        return flight
    }
    
    ///
    /// Exports a .IGC file
    ///
    func exportFlight(flightToExport: Flight) {
        
        var textToExport = ""
        
        // AXXXX - Flight ID
        textToExport = "ABCI" + (flightToExport.igcID ?? flightToExport.flightID)
        textToExport.addNewLine()
        
        // HFFXA - Fix precision
        textToExport = "HFFXA" + String(describing: flightToExport.gpsPrecision)
        textToExport.addNewLine()
        
        // HFDTE - Flight Date
        let dateValue = Calendar.current.dateComponents([.day, .month, .year], from: flightToExport.flightStartDate)
        textToExport += "HFDTE"
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
        
        for frame in flightToExport.flightFrames {
            // Date
            let dateValue = Calendar.current.dateComponents([.day, .month, .year], from: frame.timestamp)
            
            textToExport += "B"
            textToExport += String(describing: dateValue.hour)
            textToExport += String(describing: dateValue.minute)
            textToExport += String(describing: dateValue.second)
            
            // Lat
            let dms = CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude)
            textToExport += dms.coordinateToDMS()
            
            // Baro Alt
            textToExport += String(describing: frame.currentBaroAltitude)
            
            // GPS Alt
            textToExport += String(describing: frame.currentGPSAltitude)
            textToExport.addNewLine()
            #warning("TODO - In Progress")
        }        
        
    }
    
}

extension Date {
    func get(_ components: Calendar.Component..., calendar: Calendar = Calendar.current) -> DateComponents {
        return calendar.dateComponents(Set(components), from: self)
    }

    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        return calendar.component(component, from: self)
    }
}

