//
//  FlightAnalyzerService.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation

protocol FlightAnalyzerService {
    func analyzeCurrentFLight()
    func analyzeFlight(flightToAnalyze: Flight)
    func analyzeStoredFlights(flightsToAnalyze: [Flight])
}
