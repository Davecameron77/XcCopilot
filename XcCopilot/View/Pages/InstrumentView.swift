//  InstrumentView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI

struct InstrumentView: View {
    @EnvironmentObject var vm: XcCopilotViewModel
    
    var body: some View {
        
        NavigationView {
            VStack {
                Button(vm.flightComputer.inFlight ? "End Flight" : "Start Flight") {
                    if vm.flightComputer.inFlight {
                        vm.flightComputer.stopFlying()
                    } else {
                        vm.flightComputer.startFlying()
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
                            InstrumentBox(label: "Dummy", value: "69")
                        }
                        Divider()
                        HStack {
                            InstrumentBox(
                                label: "Vertical Speed: ",
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
        .padding(0)
    }
}

struct InstrumentRow<T: StringProtocol>: View {
    var label: String = "Measurement: "
    var value: T
    var unit: String?
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
            Text(unit ?? "")
        }
        .padding(.vertical, 3)
        .font(.title2)
    }
}
