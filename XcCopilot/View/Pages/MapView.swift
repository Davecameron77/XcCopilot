//
//  MapView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import MapKit

struct MapView: View {
    @Namespace var mapScope
    @EnvironmentObject var vm: XcCopilotViewModel
    @State private var glideRange = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Map(position: $vm.mapPosition, interactionModes: .all, scope: mapScope) {
                    // Location
                    UserAnnotation(anchor: .center)
                    
                    // Glide range
                    MapCircle(center: vm.gpsCoords, radius: CLLocationDistance(glideRange))
                    .stroke(lineWidth: 10)
                    .foregroundStyle(.blue.opacity(0.5))
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton(scope: mapScope)
                    MapCompass(scope: mapScope)
                }
                .onMapCameraChange { context in
                    calculateGlideRangeToDisplay(forContext: context, withGeometry: geometry)
                }
                VStack {
                    HStack {
                        WeatherView(vm: vm, currentWeather: vm.currentWeather)
                        Spacer()
                    }
                    
                    Spacer()
                    NearestThermalView(direction: vm.nearestThermalHeading, distance: vm.nearestThermalDistance)
                    
                    MapInstrumentView(
                        vm: vm,
                        calculatedElevation: vm.calculatedElevation,
                        verticalVelocityMetresPerSecond: vm.verticalVelocityMetresPerSecond,
                        gpsSpeed: vm.gpsSpeed
                    )
                }
            }
        }
    }
    
    func calculateGlideRangeToDisplay(forContext context: MapCameraUpdateContext, 
                                      withGeometry geometry: GeometryProxy) {
        
        let center = context.camera.centerCoordinate
        let span = context.region.span
        
        // Top reference of map
        let loc1 = CLLocation(latitude: center.latitude - span.latitudeDelta * 0.5,
                              longitude: center.longitude)
        // Bottom reference of map
        let loc2 = CLLocation(latitude: center.latitude + span.latitudeDelta * 0.5,
                              longitude: center.longitude)
        // Map height in Meters
        let screenHeightMeters = Measurement(value: loc1.distance(from: loc2),
                                             unit: UnitLength.meters).value
        
        let pxPerMeter = geometry.size.height / screenHeightMeters
        glideRange = vm.glideRangeInMetres * pxPerMeter
    }
}

#Preview {
    MapView()
        .environmentObject(XcCopilotViewModel())
}
