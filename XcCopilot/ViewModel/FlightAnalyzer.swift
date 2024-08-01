//
//  FlightAnalyzer.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-29.
//

import MapKit

class FlightAnalyzer: FlightAnalyzerService {
    
    var results: DmsQuadtree?
    let TREE_CAPACITY = 20
    
    func analyzeStoredFlights(_ flights: [Flight], aroundCoords coords: CLLocationCoordinate2D, withinSpan span: MKCoordinateSpan) throws -> DmsQuadtree {
        
        guard !flights.isEmpty else { throw FlightAnalyzerError.noDataProvided("No flights to analyze") }
        let region = MKCoordinateRegion(center: coords, span: span)
        results = DmsQuadtree(region: MyCoordinateRegion(region: region, count: 0), capacity: TREE_CAPACITY)
                
        for flight in flights {
            if let frames = flight.frames?.allObjects as? [FlightFrame] {
                for frame in frames {
                    
                    if !region.contains(coords: CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude)) {
                        continue
                    }
                    
                    if frame.verticalSpeed > 0.5 || frame.derrivedVerticalSpeed > 0.5 {
                        
                        let node = MapMark(
                            coords: CLLocationCoordinate2D(
                                latitude: frame.latitude,
                                longitude: frame.longitude
                            ),
                            altitude: frame.baroAltitude,
                            verticalSpeed: frame.verticalSpeed != 0 ? frame.verticalSpeed : frame.derrivedVerticalSpeed
                        )
                        
                        _ = results!.insert(node)
                    }
                }
            }
        }
        
        if results == nil {
            throw FlightAnalyzerError.noResultsFound("No results found")
        } else {
            return results!
        }
    }
}
