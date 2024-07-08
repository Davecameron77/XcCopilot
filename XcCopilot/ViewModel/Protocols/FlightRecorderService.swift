//
//  FlightRecorderService.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import CoreMotion
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import WeatherKit

protocol FlightRecorderService {
    var delegate: ViewModelDelegate? { get set }
    
    func armForFlight()
    func storeFrame(
        acceleration: CMAcceleration,
        gravity: CMAcceleration,
        gpsAltitude: Double,
        gpsCourse: Double,
        gpsCoords: CLLocationCoordinate2D,
        baroAltitude: Double,
        verticalVelocity: Double
    ) throws
    func endFlight(withWeather weather: Weather?) throws
    func getFlights() throws -> [Flight]
    func getFrames(forFlight flight: Flight) throws -> [FlightFrame]
    func updateFlightTitle(forFlight flight: Flight, withTitle title: String) throws
    func deleteFlight(_ flight: Flight) throws
    func importFlight(forUrl url: URL) async throws -> Bool
    func exportFlight(flightToExport: Flight) async throws -> IgcFile
}

enum FlightRecorderError: Error {
    case invalidIgcData(String)
    case invalidState(String)
    case recordingFailure(String)
}

extension UTType {
    static var igcType: UTType {
        UTType(exportedAs: "ca.tinyweb.xccopilot.igc")
    }
}

struct IgcFile: FileDocument {
    static var readableContentTypes = [UTType.plainText, UTType.igcType]
    static var writeableContentTypes = [UTType.igcType]
    
    var text = ""
    var hasNoContent: Bool {
        return text.count == 0
    }

    init(initialText: String = "") {
        text = initialText
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

enum CdError: Error {
    case invalidState(String)
    case recordingFailure(String)
    case noRecordsFound(String)
}
