//
//  GaugeInstrument.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-09.
//

import SwiftUI

struct GaugeInstrument: View {
    let type: GaugeType
    let label: String
    let unit: String
    let minimum: Double
    let maximum: Double
    var currentValue: Double
    var displayValue: String {
        String(format: "%.1f", currentValue)
    }
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
            
            if type == .gauge {
                Gauge(value: currentValue, in: minimum...maximum) {
                    Text(unit)
                } currentValueLabel: {
                    Text("\(Int(currentValue))")
                } minimumValueLabel: {
                    Text("\(Int(minimum))")
                } maximumValueLabel: {
                    Text("\(maximum > 1000 ? "1k+" : String(format: "%0.f", maximum))")
                }
                .gaugeStyle(.accessoryCircular)
                Text(unit)
            } else {
                Text("\(displayValue) \(unit)")
                    .font(.title2)
                    .padding()
            }
            
            
        }
    }
    
    func instrumentBackground() -> some View {
        modifier(InstrumentBackground())
    }
}

#Preview {
    GaugeInstrument(
        type: .gauge,
        label: "Groundspeed",
        unit: "km/h",
        minimum: 0,
        maximum: 40,
        currentValue: 34
    )
}
