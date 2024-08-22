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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Map(position: $vm.mapPosition, interactionModes: .all, scope: mapScope) {
                    // Location
                    UserAnnotation(anchor: .center)
                    
                    // Glide range
                    MapCircle(center: vm.gpsCoords, radius: CLLocationDistance(vm.glideRangeInPixels))
                        .stroke(lineWidth: 10)
                        .foregroundStyle(.blue.opacity(0.35))
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton(scope: mapScope)
                    MapCompass(scope: mapScope)
                }
                .onMapCameraChange { context in
                    vm.calculateGlideRangeToDisplay(forContext: context, withGeometry: geometry)
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
                        verticalVelocityMetresPerSecond: vm.verticalSpeedMps,
                        gpsSpeed: vm.gpsSpeed
                    )
                }
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(XcCopilotViewModel())
}
