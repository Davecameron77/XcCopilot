//
//  FlightAnalyzer.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-29.
//

import MapKit

class FlightAnalyzer: FlightAnalyzerService {
    
    private let TREE_CAPACITY = 20
    
    ///
    /// Analyzes a provided list of stored flights, returning a QuadTree representing the regions where the most vertical velocity is found
    ///
    /// - Parameter flights: The list of flights to search
    /// - Parameter aroundCoords: The centre coords to search the given flights
    /// - Parameter withinSpan: The span around centre coords to search
    /// - Returns a QuadTree of DMS coords, with each region indicating how many records are found
    func analyzeStoredFlights(_ flights: [Flight], aroundCoords coords: CLLocationCoordinate2D, withinSpan span: MKCoordinateSpan) throws -> DmsQuadtree {
        
        guard !flights.isEmpty else { throw FlightAnalyzerError.noDataProvided("No flights to analyze") }
        let region = MKCoordinateRegion(center: coords, span: span)
        let results = DmsQuadtree(region: MyCoordinateRegion(region: region, count: 0), capacity: TREE_CAPACITY)
                
        for flight in flights {
            if let frames = flight.frames?.allObjects as? [FlightFrame] {
                for frame in frames {
                    
                    if !region.contains(coords: CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude)) {
                        continue
                    }
                    
                    if frame.verticalSpeed > 0.25 || frame.derrivedVerticalSpeed > 0.25 {
                        
                        let node = MapMark(
                            coords: CLLocationCoordinate2D(
                                latitude: frame.latitude,
                                longitude: frame.longitude
                            ),
                            altitude: frame.baroAltitude,
                            verticalSpeed: frame.verticalSpeed != 0 ? frame.verticalSpeed : frame.derrivedVerticalSpeed
                        )
                        
                        _ = results.insert(node)
                    }
                }
            }
        }
        
        return results
    }
}
