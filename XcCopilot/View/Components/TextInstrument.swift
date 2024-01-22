//
//  TextInstrument.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-19.
//

import SwiftUI

struct TextInstrument: View {
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
            Text("\(displayValue) \(unit)")
                .font(.title2)
        }
    }
    
    func instrumentBackground() -> some View {
        modifier(InstrumentBackground())
    }
}

#Preview {
    TextInstrument(label: "Temperature", unit: "°C", minimum: 0.0, maximum: 50.0, currentValue: 14.0)
}
