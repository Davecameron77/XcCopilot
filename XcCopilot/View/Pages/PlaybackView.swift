//
//  PlaybackView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-03-12.
//

import SwiftUI
import MapKit
import Charts

struct PlaybackView: View {
    
    @State private var region: MapCameraPosition = MapCameraPosition.automatic
    @Namespace var mapScope
    
    @State private var pathIndex = 0.0
    @State private var playing = false
    @State private var elapsedTimeInSeconds = 0.0
    @State private var totalTimeInSeconds = 0.0
    @State private var playbackAltitude = 0.0
    @State private var playbackSpeed = 0.0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var nodes: [HashableNode]
        
    private var printedElapsedTime: String {
        let hours = Int(elapsedTimeInSeconds) / 3600
        let minutes = (Int(elapsedTimeInSeconds) % 3600) / 60
        let seconds = Int(elapsedTimeInSeconds) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var printedTimeRemaining: String {
        let timeRemainingInSeconds = totalTimeInSeconds - elapsedTimeInSeconds
        let hours = Int(timeRemainingInSeconds) / 3600
        let minutes = (Int(timeRemainingInSeconds) % 3600) / 60
        let seconds = Int(timeRemainingInSeconds) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    var body: some View {
                       
        List {
            // Controls
            if !nodes.isEmpty {
                Section {
                    VStack {
                        HStack {
                            
                            Text(printedElapsedTime)
                            Slider(value: $pathIndex, in: 0...Double(nodes.count))
                            Text(printedTimeRemaining)
                        }
                        HStack {
                            Button {
                                playing.toggle()
                            } label: {
                                Image(systemName: playing ? "pause.fill" : "play.fill")
                                    .padding()
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Speed:")
                                    .font(.title3)
                                Text("\(String(format: "%.1f", playbackSpeed)) km/h")
                                    .font(.title3)
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading) {
                                Text("Altitude: ")
                                    .font(.title3)
                                Text("\(String(format: "%.1f", playbackAltitude)) m")
                                    .font(.title3)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            // Map
            Section {
                Map(position: $region, scope: mapScope) {
                    if !nodes.isEmpty {
                        Marker("Launch",
                               coordinate: CLLocationCoordinate2D(latitude: nodes.first!.latitude,
                                                                  longitude: nodes.first!.longitude))
                        Marker("Landing",
                               coordinate: CLLocationCoordinate2D(latitude: nodes.last!.latitude,
                                                                  longitude: nodes.last!.longitude))
                        
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: nodes[Int(pathIndex)].latitude,
                                                                          longitude: nodes[Int(pathIndex)].longitude)) {
                            Image("icon")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(.black)
                                .font(.title)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                )
                        }
                        
                        MapPolyline(coordinates: nodes.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        })
                        .stroke(.red, lineWidth: 2.0)
                    }
                }
                .frame(minHeight: 300)
            } header: {
                Text("Path")
            }
            
            // Altitude profile
            Section {
                Chart(self.nodes) {
                    RuleMark(y: .value("Launch", nodes.first?.altitude ?? 0.0))
                        .foregroundStyle(Color.mint)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .annotation(alignment: .trailing) {
                            Text("Launch")
                                .font(.caption)
                                .foregroundColor(Color.mint)
                        }
                    RuleMark(y: .value("Landing", nodes.last?.altitude ?? 0.0))
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .annotation(alignment: .leading) {
                            Text("Landing")
                                .font(.caption)
                                .foregroundColor(Color.red)
                        }
                    
                    PointMark(x: .value("Time", nodes[Int(pathIndex)].timestamp),
                              y: .value("Altitude", nodes[Int(pathIndex)].altitude))
                    
                    LineMark(
                        x: .value("Time", $0.timestamp),
                        y: .value("Altitude", $0.altitude)
                    )
                    .foregroundStyle(Color.red.gradient)
                    .interpolationMethod(.linear)
                    .lineStyle(.init(lineWidth: 2))
                }
                .frame(minHeight: 200)
                .chartPlotStyle { plotContent in
                    plotContent
                        .backgroundStyle(.black.gradient.opacity(0.75))
                }
            } header: {
                Text("Altitude Profile")
            }
        }
        .listStyle(.inset)
        .navigationTitle("Flight Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task.detached(priority: .userInitiated) {
                await setup()
            }
        }
        .onReceive(timer) { input in
            if playing {
                pathIndex += 1
                elapsedTimeInSeconds += 1
                playbackAltitude = nodes[Int(pathIndex)].altitude
                
                let distance = haversineDistance(from: coordinateFromNode(nodes[Int(pathIndex)]),
                                                 to: coordinateFromNode(nodes[Int(pathIndex) - 1]))
                playbackSpeed = distance * 60 * 60
            }
        }
    }
    
    
}

// Functions
extension PlaybackView {
    private func setup() {
        let maxLatitude  = self.nodes.max { a, b in a.latitude < b.latitude }?.latitude ?? 0.0
        let minLatitude  = self.nodes.min { a, b in a.latitude < b.latitude }?.latitude ?? 0.0
        let maxLongitude = self.nodes.max { a, b in a.longitude < b.longitude }?.longitude ?? 0.0
        let minLongitude = self.nodes.min { a, b in a.longitude < b.longitude }?.longitude ?? 0.0
        let centerLat    = (minLatitude + maxLatitude) / 2
        let centerLong   = (minLongitude + maxLongitude) / 2
        
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLong)
        
        region =  MapCameraPosition.region(MKCoordinateRegion(center: center,
                                                              span: MKCoordinateSpan(latitudeDelta: abs(maxLatitude - minLatitude) + 0.005,
                                                                                     longitudeDelta: abs(maxLongitude - minLongitude + 0.005))))
        
        if let start = self.nodes.min(by: { a, b in a.timestamp < b.timestamp })?.timestamp,
           let end = self.nodes.max(by: { a, b in a.timestamp < b.timestamp })?.timestamp {
            totalTimeInSeconds = end.timeIntervalSince(start)
        }
    }
    
    private func haversineDistance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let R = 6371.0 // Radius of the Earth in kilometers
        let lat1 = coord1.latitude.degreesToRadians
        let lon1 = coord1.longitude.degreesToRadians
        let lat2 = coord2.latitude.degreesToRadians
        let lon2 = coord2.longitude.degreesToRadians
        
        let dlat = lat2 - lat1
        let dlon = lon2 - lon1
        
        let a = sin(dlat / 2) * sin(dlat / 2) + cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return R * c
    }
    
    private func coordinateFromNode(_ node: HashableNode) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: node.latitude, longitude: node.longitude)
    }
}
