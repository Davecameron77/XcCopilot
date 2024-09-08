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
    @State private var playbackVerticalSpeed = 0.0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var nodes: [HashableNode]
        
    @State private var printedElapsedTime = ""
    @State private var printedTimeRemaining = ""
    
    var body: some View {
                       
        List {
            // Controls
            if !nodes.isEmpty {
                Section {
                    VStack {
                        HStack {
                            Text(printedElapsedTime)
                            Slider(value: $pathIndex, in: 0...Double(nodes.count))
                                .onChange(of: pathIndex) { oldValue, newValue in
                                    pathIndex = newValue
                                    elapsedTimeInSeconds = nodes.first!.timestamp.distance(to: nodes[Int(pathIndex)].timestamp)
                                    updateTimings()
                                }
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
                            
                            VStack(alignment: .center) {
                                Text("Speed:")
                                Text("\(String(format: "%.1f", playbackSpeed)) km/h")
                            }
                            .frame(width: 70)
                            .font(.subheadline)
                            .padding(.horizontal, 5)
                            
                            VStack(alignment: .center) {
                                Text("Altitude: ")
                                Text("\(String(format: "%.1f", playbackAltitude)) m")
                            }
                            .frame(width: 70)
                            .font(.subheadline)
                            .padding(.horizontal, 5)
                            
                            VStack(alignment: .center) {
                                Text("Vert. Speed: ")
                                Text("\(String(format: "%.1f", playbackVerticalSpeed)) m/s")
                            }
                            .frame(width: 70)
                            .font(.subheadline)
                            .padding(.horizontal, 5)
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
                if elapsedTimeInSeconds == totalTimeInSeconds {
                    return
                }
                
                elapsedTimeInSeconds += 1
                updateTimings()
            }
        }
    }
    
    
}

// Functions
extension PlaybackView {
    
    ///
    /// Sets up flight params for display
    ///
    private func setup() {
        // Set timers
        updateTimings()
        
        if let start = self.nodes.min(by: { a, b in a.timestamp < b.timestamp })?.timestamp,
           let end = self.nodes.max(by: { a, b in a.timestamp < b.timestamp })?.timestamp {
            totalTimeInSeconds = end.timeIntervalSince(start)
        }
        
        // Set map scope
        let maxLatitude  = self.nodes.max { a, b in a.latitude < b.latitude }?.latitude ?? 0.0
        let minLatitude  = self.nodes.min { a, b in a.latitude < b.latitude }?.latitude ?? 0.0
        let maxLongitude = self.nodes.max { a, b in a.longitude < b.longitude }?.longitude ?? 0.0
        let minLongitude = self.nodes.min { a, b in a.longitude < b.longitude }?.longitude ?? 0.0
        let centerLat    = (minLatitude + maxLatitude) / 2
        let centerLong   = (minLongitude + maxLongitude) / 2
        
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLong)
        
        region =  MapCameraPosition.region(
            MKCoordinateRegion(center: center,
                               span: MKCoordinateSpan(latitudeDelta: abs(maxLatitude - minLatitude) + 0.005,
                                                      longitudeDelta: abs(maxLongitude - minLongitude + 0.005))))
    }
    
    private func updateTimings() {
        
        // Timestamp: Start of playback
        let first = nodes.first?.timestamp
        // Current applicable timestamp
        let currentTs = first?.addingTimeInterval(elapsedTimeInSeconds)
        // Time remaining in playback
        let timeRemainingInSeconds = totalTimeInSeconds - elapsedTimeInSeconds
        
        // For printing
        let hoursElapsed = Int(elapsedTimeInSeconds) / 3600
        let minutesElapsed = (Int(elapsedTimeInSeconds) % 3600) / 60
        let secondsElapsed = Int(elapsedTimeInSeconds) % 60
        
        let hoursRemaining = Int(timeRemainingInSeconds) / 3600
        let minutesRemaining = (Int(timeRemainingInSeconds) % 3600) / 60
        let secondsRemaining = Int(timeRemainingInSeconds) % 60

        // Update view
        withAnimation {
            if nodes[Int(pathIndex) + 1].timestamp == currentTs {
                pathIndex += 1
            }
            
            printedElapsedTime = String(format: "%02d:%02d:%02d", hoursElapsed, minutesElapsed, secondsElapsed)
            printedTimeRemaining = String(format: "%02d:%02d:%02d", hoursRemaining, minutesRemaining, secondsRemaining)
            
            playbackAltitude = nodes[Int(pathIndex)].altitude
            playbackVerticalSpeed = nodes[Int(pathIndex)].verticalSpeed != 0.0 ? nodes[Int(pathIndex)].verticalSpeed : nodes[Int(pathIndex)].derrivedVerticalSpeed
            
            if pathIndex > 1 {
                let distance = haversineDistance(
                    from: CLLocationCoordinate2D(latitude: nodes[Int(pathIndex)].latitude, longitude: nodes[Int(pathIndex)].longitude),
                    to: CLLocationCoordinate2D(latitude: nodes[Int(pathIndex) - 1].latitude, longitude: nodes[Int(pathIndex) - 1].longitude)
                )
                
                let lastTs = nodes[Int(pathIndex) - 1].timestamp
                let secondsSinceLastUpdate = lastTs.distance(to: currentTs!)
                let playbackSpeedMps = (distance / 1000) / secondsSinceLastUpdate
                
                playbackSpeed = (playbackSpeedMps * 3600) / 1000
            }
        }
    }
    
    ///
    /// Utility func to calculate distance between two DMS, from which speed can be derrived
    ///
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
}
