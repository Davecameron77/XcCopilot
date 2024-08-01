//
//  FlightAnalyzerService.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation
import MapKit

protocol FlightAnalyzerService {
    func analyzeStoredFlights(
        _ flights: [Flight],
        aroundCoords coords: CLLocationCoordinate2D,
        withinSpan span: MKCoordinateSpan
    ) throws -> DmsQuadtree
}

enum FlightAnalyzerError: Error {
    case noDataProvided(String)
    case noResultsFound(String)
}
