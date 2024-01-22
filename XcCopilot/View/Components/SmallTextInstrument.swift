//
//  SmallTextInstrument.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-01-13.
//

import SwiftUI

struct SmallTextInstrument: View {
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
                .font(.subheadline)
            Text("\(displayValue) \(unit)")
                .font(.headline)
        }
        .minimumScaleFactor(0.1)
    }
    
    func instrumentBackground() -> some View {
        modifier(InstrumentBackground())
    }
}

#Preview {
    SmallTextInstrument(label: "Temperature", unit: "°C", minimum: 0.0, maximum: 50.0, currentValue: -14.0)
}
