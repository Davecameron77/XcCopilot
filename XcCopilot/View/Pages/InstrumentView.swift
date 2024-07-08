//  InstrumentView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import SwiftData
import WeatherKit

struct InstrumentView: View {
    @EnvironmentObject var vm: XcCopilotViewModel
    @Environment(\.modelContext) var context
        
    var body: some View {
        
        NavigationView {
            VStack {
                Button {
                    if vm.flightState == .landed {
                        vm.armForFlight()
                    } else if vm.flightState == .armed {
                        vm.startFlying()
                    } else {
                        vm.stopFlying()
                    }
                } label: {
                    switch vm.flightState {
                    case .landed:
                        Text("Arm for Flight")
                    case .armed:
                        Text("Begin Flight")
                    case .inFlight:
                        Text("End Flight")
                    }
                }
                .font(.title)
                .padding(.vertical, 10)
                .tint(vm.flightComputer.inFlight ? .red : .green)
                .buttonStyle(.borderedProminent)
                
                ScrollView {
                    VStack {
                        Divider()
                        
                        HStack {
                            InstrumentBox(label: "Flight Time", value: vm.flightTime.formatted())
                            Divider()
                            InstrumentBox(
                                label: "Glide Ratio", 
                                value: String(vm.glideRatio) + " / 1",
                                unit: ""
                            )
                        }
                        
                        Divider()
                        
                        HStack {
                            InstrumentBox(
                                label: "Vertical Speed",
                                value: String(format: "%.2f", vm.verticalVelocityMetresPerSecond),
                                unit: vm.verticalSpeedUnit.rawValue
                            )
                            Divider()
                            InstrumentBox(
                                label: "Vertical Accel",
                                value: String(format: "%.2f", vm.verticalAccelerationMetresPerSecondSquared),
                                unit: "m/s²"
                            )
                        }
                        
                        Divider()
                        
                        HStack {
                            InstrumentBox(
                                label: "Baro Altitude",
                                value: String(format: "%.1f", vm.baroAltitude),
                                unit: vm.elevationUnit.rawValue
                            )
                            Divider()
                            InstrumentBox(
                                label: "GPS Altitude",
                                value: String(format: "%.1f", vm.gpsAltitude),
                                unit: vm.elevationUnit.rawValue
                            )
                        }
                        
                        Divider()
                        
                        HStack {
                            InstrumentBox(
                                label: "Elevation",
                                value: String(format: "%.1f", vm.calculatedElevation),
                                unit: vm.elevationUnit.rawValue
                            )
                            Divider()
                            InstrumentBox(
                                label: "Groundspeed",
                                value: String(format: "%.1f", vm.gpsSpeed),
                                unit: vm.speedUnit.rawValue
                            )
                        }
                        
                        Divider()
                        
                        HStack {
                            InstrumentBox(
                                label: "Heading",
                                value: String(format: "%.1f", vm.magneticHeading),
                                unit: "°"
                            )
                            Divider()
                            InstrumentBox(
                                label: "Course",
                                value: String(format: "%.1f", vm.gpsCourse),
                                unit: "°"
                            )
                        }
                        
                        Divider()
                    }
                }
            }
            .navigationTitle("Instruments")
        }
        
    }
}

#Preview {
    InstrumentView()
        .environmentObject(XcCopilotViewModel())
}
