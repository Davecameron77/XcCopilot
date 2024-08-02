//
//  FlightView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-18.
//

import SwiftUI
import CoreLocation
import MapKit
import SwiftData
import Charts
import UniformTypeIdentifiers

struct FlightView: View {
    @EnvironmentObject var vm: XcCopilotViewModel
    @State private var flight: Flight
    @State private var frames = [FlightFrame]()
    @State private var flightName = "" 
    @State private var region = MapCameraPosition.automatic
    @State private var exportPanelOpen = false
    @State private var exportedFile = IgcFile()
    @State private var path: [HashableNode] = []
    @State private var launchAlt = 0.0
    @State private var maxAlt = 0.0
    @State private var landAlt = 0.0
    @State private var fileToExport = IgcFile(initialText: "")
    
    init(flight: Flight) {
        self.flight = flight
    }
        
    var body: some View {
        
        List {
            Section(header: Text("Profile")) {
                NavigationLink(value: path) {
                    Text("View Playback")
                }
            }
            
            Section(header: Text("Details")) {
                TextField("", text: $flightName)
                    .font(.title)
                Text("Flight Start: \(flight.startDate ?? Date.distantPast, format: .dateTime)")
                Text("Flight End: \(flight.endDate ?? Date.distantPast, format: .dateTime)")
                Text("Flight Duration: \(flight.duration ?? "")")
                Text("Launch Altitude: \(launchAlt.formatted(.number.precision(.fractionLength(1))))")
                Text("Max Altitude: \(maxAlt.formatted(.number.precision(.fractionLength(1))))")
                Text("Land Altitude: \(landAlt.formatted(.number.precision(.fractionLength(1))))")
            }
            
            Section(header: Text("Path")) {
                Map(position: $region) {
                    Marker("Launch",
                           coordinate: CLLocationCoordinate2D(latitude: flight.launchLatitude,
                                                              longitude: flight.launchLongitude))
                    Marker("Landing",
                           coordinate: CLLocationCoordinate2D(latitude: flight.landLatitude,
                                                              longitude: flight.landLongitude))
                    MapPolyline(coordinates: path.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(.red, lineWidth: 2.0)
                }
                .frame(minHeight: 250)
            }
        }
        .onAppear {

            Task(priority: .high) {
                self.fileToExport = await self.vm.exportIgcFile(flight: flight) ?? IgcFile(initialText: "")
            }
            flightName = flight.title ?? "Unknown Flight"
            
            if var frames = flight.frames?.allObjects as? [FlightFrame] {
                frames.sort(by: { $0.timestamp! < $1.timestamp! })
                
                launchAlt = frames.min(by: {
                    a, b in a.timestamp! < b.timestamp!
                })?.baroAltitude ?? 0.0
                
                maxAlt = frames.max(by: {
                    a, b in a.baroAltitude < b.baroAltitude
                })?.baroAltitude ?? 0.0
                
                landAlt = frames.max(by: {
                    a, b in a.timestamp! < b.timestamp!
                })?.baroAltitude ?? 0.0
                
                path = frames.map {
                    HashableNode(timestamp: $0.timestamp!,
                                 latitude: $0.latitude,
                                 longitude: $0.longitude,
                                 altitude: $0.baroAltitude,
                                 verticalSpeed: $0.verticalSpeed,
                                 derrivedVerticalSpeed: $0.derrivedVerticalSpeed)
                }
                
                let maxLatitude  = path.max { a, b in a.latitude < b.latitude }?.latitude ?? 0.0
                let minLatitude  = path.min { a, b in a.latitude < b.latitude }?.latitude ?? 0.0
                let maxLongitude = path.max { a, b in a.longitude < b.longitude }?.longitude ?? 0.0
                let minLongitude = path.min { a, b in a.longitude < b.longitude }?.longitude ?? 0.0
                let centerLat    = (minLatitude + maxLatitude) / 2
                let centerLong   = (minLongitude + maxLongitude) / 2
                
                let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLong)
                
                region = MapCameraPosition.region(
                    MKCoordinateRegion(center: center,
                                       span: MKCoordinateSpan(latitudeDelta: abs(maxLatitude - minLatitude) + 0.005,
                                                              longitudeDelta: abs(maxLongitude - minLongitude + 0.005))))
            }
        }
        .navigationTitle(flight.title ?? "Unknown Flight")
        .navigationDestination(for: [HashableNode].self) { path in
            PlaybackView(nodes: path)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: flightName) {
            Task(priority: .userInitiated) {
                vm.updateFlightTitle(flightToUpdate: flight, withTitle: flightName)
            }
        }
        .toolbar {
            Button {
                exportPanelOpen = true
            }
            label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .fileExporter(isPresented: $exportPanelOpen,
                      document: fileToExport,
                      contentType: UTType.igcType,
                      defaultFilename: "\(flight.title ?? "Unknown flight")") { result in
            
            switch result {
            case .success(let url):
                print("Saved to \(url)")
                break
            case .failure(let error):
                print(error)
                break
            }
        }
    }
}

//#Preview {
//    FlightView(flight: Flight.dummyFlight)
//}
