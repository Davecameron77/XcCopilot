//
//  GaugeInstrument.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-09.
//

import SwiftUI

struct GaugeInstrument: View {
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
                .font(.headline)
            
            Spacer()
            
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
            Spacer()
        }
        .padding()
        .frame(minWidth: 100, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
        .cornerRadius(10)
        .padding(5)
    }
}

#Preview {
    GaugeInstrument(label: "Groundspeed", unit: "km/h", minimum: 0, maximum: 40, currentValue: 34)
}
