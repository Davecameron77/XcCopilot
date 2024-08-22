//
//  Fragments.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-06-15.
//

import SwiftUI
import WeatherKit

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
        if !distance.isNaN && !direction.isNaN {
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
                Text("\(verticalVelocityMetresPerSecond, specifier: "%.1f") \(vm.verticalSpeedUnit.rawValue)")
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

struct InstrumentBox<T: StringProtocol>: View {
    var label: String = "Measurement: "
    var value: T
    var unit: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label):")
                .font(.title2)
                .padding(5)
            Spacer()
            HStack {
                Spacer()
                Text(value)
                Text(unit ?? "")
            }
            .font(.title)
            .padding(3)
        }
    }
}

struct WindBox: View {
    var direction: String
    var velocity: String
    var unit: String?
    
    var body: some View {
        if Double(velocity) ?? 0.0 > 0.0  && Double(velocity) ?? 0.0 < 25.0 {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wind:")
                    .font(.title2)
                    .padding(5)
                HStack {
                    Image(systemName: "arrowshape.up.fill")
                        .resizable()
                        .frame(width: 15, height: 30)
                        .rotationEffect(Angle(degrees: Double(direction) ?? 0.0))
                }
                .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
                Spacer()
                HStack {
                    Text("\(direction)°")
                        .font(.system(size: 18))
                    Text("at \(velocity) \(unit ?? "m/s")")
                        .font(.system(size: 18))
                }
                .padding(.bottom, 10)
            }
            .frame(width: 185, height: 90)
        } else {
            Text("N/A")
                .font(.title)
                .frame(width: 185, height: 80)
        }
    }
}

struct FlightCard: View {
    let flight: Flight
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(flight.title ?? "Unknown Flight")
                .font(.title3)
            HStack {
                Text(flight.startDate ?? Date.now, style: .date)
                Spacer()
                Text(flight.duration ?? "00:00:00")
            }
            .font(.subheadline)
        }
    }
}
