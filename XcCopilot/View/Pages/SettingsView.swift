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
    @Environment(\.modelContext) var context
    @FocusState var isInputActive: Bool
    
    @Query(sort: \Glider.name) var gliders: [Glider]
    
    var body: some View {
        NavigationStack {
            Form {
                List {
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
                        Picker("Gauge Type", selection: $vm.gaugeType) {
                            ForEach(GaugeType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                    
                    Section("Glider Info") {
                        TextField("Glider Model", text: $vm.gliderName)
                        VStack(alignment: .leading) {
                            Text("Trim Speed: \(String(format: "%.0f", vm.trimSpeed)) km/h")
                            Slider(value: $vm.trimSpeed, in: 28...40) {
                                Text("Trim Speed: \(String(format: "%.0f", vm.trimSpeed)) km/h")
                            }
                        }
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
