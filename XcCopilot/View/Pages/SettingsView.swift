//
//  SettingsView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var vm: XcCopilotViewModel
    @FocusState var isInputActive: Bool
    @State private var pilotName: String = "John Doe"
    @State private var gliderName: String = "Independance Pioneer"
    
    var body: some View {
        NavigationStack {
            Form {
                List {
                    Section("Pilot") {
                        LabeledContent {
                            TextField("Pilot: ", text: $pilotName)
                        } label: {
                          Text("Pilot:")
                        }
                        LabeledContent {
                            TextField("Glider: ", text: $gliderName)
                        } label: {
                            Text("Glider: ")
                        }
                    }
                    
                    Section("Units") {
                        Picker("Speed Units", selection: $vm.speedUnit) {
                            ForEach(SpeedUnits.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        
                        Picker("Elevation Units", selection: $vm.elevationUnit) {
                            ForEach(ElevationUnits.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        
                        Picker("Vertical Speed Units", selection: $vm.verticalSpeedUnit) {
                            ForEach(VerticalSpeedUnits.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        
                        Picker("Temperature Units", selection: $vm.temperatureUnit) {
                            ForEach(TemperatureUnits.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                    }
                    
                    Section("System") {
                        Toggle("Audio:", isOn: $vm.audioActive)
                        VStack(alignment: .leading) {
                            Text("Vario Audio: \(String(format: "%.0f", vm.varioVolume)) %")
                            Slider(value: $vm.varioVolume, in:0...100, step: 10)
                        }
                    }
                    
                    Section("Status") {
                        Text("GPS Available: \(vm.gpsAvailable ? "True" : "False")")
                        Text("Alt Available: \(vm.gpsAvailable ? "True" : "False")")
                        Text("Motion Available: \(vm.gpsAvailable ? "True" : "False")")
                        Text("Ready to Fly: \(vm.readyToFly ? "True" : "False")")
                    }
                }
                .navigationTitle("Settings")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(XcCopilotViewModel())
}
