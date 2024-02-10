//
//  MapView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import MapKit
import WeatherKit

struct MapView: View {
    @Namespace var mapScope
    @EnvironmentObject var vm: XcCopilotViewModel
    @State private var glideRange: Double = .nan
    
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
                    NearestThermalView(direction: vm.nearestThermalDistance, distance: vm.nearestThermalDistance)
                    
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

struct WeatherView: View {
    var vm: XcCopilotViewModel
    var currentWeather: Weather?
    
    var body: some View {
        
            VStack(spacing: 5) {
                if currentWeather != nil {
                   
                    HStack {
                        Text("\(currentWeather!.currentWeather.temperature.converted(to: (vm.temperatureUnit == .c ? .celsius : .fahrenheit)).value, specifier: "%.1f")°\(vm.temperatureUnit.rawValue)")
                        Image(systemName: currentWeather!.currentWeather.symbolName)
                    }
                    HStack(spacing: 1) {
                        Image(systemName: "wind")
                        Text("\(currentWeather!.currentWeather.wind.speed.value, specifier: "%.1f") G \(currentWeather!.currentWeather.wind.gust?.value ?? 0.0, specifier: "%.1f")")
                    }
                    Text("at \(currentWeather!.currentWeather.wind.direction.value, specifier: "%.1f")°")
                    
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                }
            }
            .font(.headline)
            .padding(5)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 5.0))
            .padding(10)
    }
}

struct NearestThermalView: View {
    var direction: Double = 0
    var distance: Double = 0
    
    var body: some View {
        if true {
//        if distance != 0 {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 40))
                        .rotationEffect(Angle(degrees: direction))
                    Text("\(distance, specifier: "%.1f") m")
                        .font(.title3)
                }
                .frame(width: 120, height: 120)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .padding(3)
            }
        }
        
    }
}

struct MapInstrumentView: View {
    var vm: XcCopilotViewModel
    var calculatedElevation: Double
    var verticalVelocityMetresPerSecond: Double
    var gpsSpeed: Double
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .center) {
                Text("Elevation")
                    .font(.subheadline)
                Text("\(calculatedElevation, specifier: "%.1f") \(vm.elevationUnit.rawValue)")
                    .font(.headline)
            }
            Divider()
            VStack(alignment: .center) {
                Text("Vertical Speed")
                    .font(.subheadline)
                Text("\(verticalVelocityMetresPerSecond, specifier: "%.1f") \(vm.elevationUnit.rawValue)")
                    .font(.headline)
            }
            Divider()
            VStack(alignment: .center) {
                Text("Ground Speed")
                    .font(.subheadline)
                Text("\(gpsSpeed, specifier: "%.1f") \(vm.speedUnit.rawValue)")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 80)
        .background(.ultraThinMaterial)
    }
}
