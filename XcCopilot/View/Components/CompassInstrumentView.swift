//
//  TextInstrumentView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-10.
//

import SwiftUI

struct CompassInstrumentView: View {
    let label: String
    let minimum: Double
    let maximum: Double
    let currentValue: Double
    var displayValue: String {
        String(format: "%.1f", currentValue)
    }
    
    var body: some View {
        VStack {
            Text(label)
                .font(.headline)            
            VStack {
                ZStack {
                    Circle()
                        .foregroundColor(Color.black.opacity(0.1))
                        
                    Image(systemName: "arrow.up")
                        .font(.system(size: 24.0))
                        .rotationEffect(Angle(degrees: currentValue))
                }
            }
            .frame(width: 60, height: 60)
            Text("\(displayValue) °")
        }
    }
    
    func instrumentBackground() -> some View {
        modifier(InstrumentBackground())
    }
}

#Preview {
    CompassInstrumentView(label: "Heading", minimum: 0, maximum: 360, currentValue: 45)
}
