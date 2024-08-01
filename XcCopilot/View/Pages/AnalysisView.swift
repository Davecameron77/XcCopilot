//
//  AnalysisView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-13.
//

import CoreML
import MapKit
import SwiftUI

struct AnalysisView: View {
    @Namespace var mapScope
    @EnvironmentObject var vm: XcCopilotViewModel
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 49.2357,
                                                          longitude: -121.9),
                           span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.0793)
        ))
    
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var mapSpan: MKCoordinateSpan?
    
    @State private var searchableFlights: [Flight] = []
    @State private var tree: DmsQuadtree?
    
    var body: some View {
        Map(position: $position, interactionModes: .all, scope: mapScope) {
            if tree != nil {
                ForEach(tree!.returnResults(), id: \.self) { myRegion in
                    
                    Annotation("", coordinate: myRegion.region.center) {
                        RoundedRectangle(cornerRadius: 40)
                            .fill(
                                myRegion.count > 10 ?
                                RadialGradient(
                                    stops: [.init(color: .red.opacity(0.85), location: 0.0),
                                            .init(color: .yellow.opacity(0.5), location: 0.5)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                ) :
                                    RadialGradient(
                                        stops: [.init(color: .yellow.opacity(0.75), location: 0.0),
                                                .init(color: .yellow.opacity(0.5), location: 0.15),
                                                .init(color: .green.opacity(0.25), location: 0.25),
                                                .init(color: .green.opacity(0.15), location: 0.5)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 40
                                    )
                            )
                            .blur(radius: 2.5)
                            .frame(width: 50, height: 50)
                            .opacity(myRegion.region.span.latitudeDelta > (mapSpan!.latitudeDelta * 0.1) ? 0 : 1)
                            
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView(anchorEdge: .trailing)
        }
        .safeAreaInset(edge: .bottom, content: {
            Button {
                guard mapCenter != nil && mapSpan != nil else { return }
                tree = vm.analyzeFlights(searchableFlights, aroundCoords: mapCenter!, withinSpan: mapSpan!)
            } label: {
                Text("Analyze \(searchableFlights.count) flights")
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        })
        .onAppear {
            if let center = position.region?.center,
               let span = position.region?.span {
                
                mapCenter = center
                mapSpan = span
                
                Task(priority: .userInitiated) {
                    searchableFlights = await vm.getFlightsAroundRegion(center, withSpan: span)
                }
            }
        }
        .onMapCameraChange { mapContext in
            
            mapCenter = mapContext.region.center
            mapSpan = mapContext.region.span
            
            Task(priority: .userInitiated) {
                searchableFlights = await vm.getFlightsAroundRegion(mapContext.camera.centerCoordinate, withSpan: mapContext.region.span)
            }
            
        }
    }
}

//#Preview {
//    AnalysisView()
//        .environmentObject(XcCopilotViewModel())
//}
