//
//  FlightRecorderService.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import SwiftData

protocol FlightRecorderService {
    var recording: Bool { get set }
    
    func startRecording()
    func stopRecording(context: ModelContext)
    func storeFrame(frame: FlightFrame)
    func createFlightToImport(forUrl url: URL) async throws -> Flight
    func exportFlight(flightToExport: Flight) async throws
}

