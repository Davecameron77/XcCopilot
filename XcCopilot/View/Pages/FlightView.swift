//
//  FlightView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-18.
//

import SwiftUI
import CoreLocation
import MapKit

struct FlightView: View {
    @Bindable var flight: Flight
    private let formatter = DateComponentsFormatter()
    var mapPosition: MapCameraPosition
    var coords = [CLLocationCoordinate2D]()
    
    var body: some View {
        VStack {
            Section {
                List {
                    TextField("", text: $flight.flightTitle)
                        .font(.title)
                    Text("Flight Start: \(flight.flightStartDate, format: .dateTime)")
                    Text("Flight End: \(flight.flightEndDate, format: .dateTime)")
                    Text("Flight Duration: \(flight.flightDuration)")
                }
                .listStyle(.plain)
            }
            Section {
                Map(initialPosition: mapPosition, interactionModes: .all) {
                    Marker("Launch", 
                           coordinate: CLLocationCoordinate2D(latitude: flight.launchLatitude,
                                                              longitude: flight.launchLongitude))
                    Marker("Landing", 
                           coordinate: CLLocationCoordinate2D(latitude: flight.landLatitude,
                                                              longitude: flight.landLongitude))
                }
                .mapStyle(.hybrid(elevation: .realistic))
            }
        }
        .navigationTitle(flight.flightTitle)
    }
    
    init(flight: Flight) {
        self.flight = flight
        
        mapPosition = MapCameraPosition.region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: flight.launchLatitude,
                                               longitude: flight.launchLongitude),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        )
        
        if coords.isEmpty {
            for frame in flight.flightFrames {
                let clloc = CLLocationCoordinate2D(latitude: frame.latitude, longitude: frame.longitude)
                coords.append(clloc)
            }
        }
    }
}

#Preview {
    FlightView(flight: Flight.dummyFlight)
}

struct Location: Identifiable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
}
