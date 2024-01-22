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
                .padding()
                .tint(vm.flightComputer.inFlight ? .red : .green)
                .buttonStyle(.borderedProminent)
                
                List {
                    
                    InstrumentRow(label: "Flight Time: ", value: vm.flightTime.formatted())
                    InstrumentRow(
                        label: "Vertical Speed: ",
                        value: String(format: "%.1f", vm.verticalVelocityMetresPerSecond),
                        unit: vm.verticalSpeedUnit.rawValue
                    )
                    
                    InstrumentRow(
                        label: "Baro Altitude: ",
                        value: String(format: "%.1f", vm.baroAltitude),
                        unit: vm.elevationUnit.rawValue
                    )
                    
                    InstrumentRow(
                        label: "GPS Altitude: ",
                        value: String(format: "%.1f", vm.gpsAltitude),
                        unit: vm.elevationUnit.rawValue
                    )
                    
                    InstrumentRow(
                        label: "Elevation: ",
                        value: String(format: "%.1f", vm.calculatedElevation),
                        unit: vm.elevationUnit.rawValue
                    )
                    
                    InstrumentRow(
                        label: "Groundspeed: ",
                        value: String(format: "%.1f", vm.gpsSpeed),
                        unit: vm.speedUnit.rawValue
                    )
                    
                    InstrumentRow(
                        label: "Heading: ",
                        value: String(format: "%.1f", vm.magneticHeading),
                        unit: "°"
                    )
                    
                    InstrumentRow(
                        label: "Course: ",
                        value: String(format: "%.1f", vm.gpsCourse),
                        unit: "°"
                    )
                }
                .navigationTitle("Instruments")
            }
            
        }
        
    }
}

#Preview {
    InstrumentView()
        .environmentObject(XcCopilotViewModel())
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
        .font(.title)
    }
}
