//
//  TextInstrumentView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-10.
//

import SwiftUI

struct CompassInstrumentView: View {
    let label: String
    let unit: String
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
            Spacer()
            
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
            Text("\(displayValue)°")
            Spacer()
        }
        .padding()
        .frame(minWidth: 150, maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
        .cornerRadius(10)
        .padding(5)
    }
}

#Preview {
    CompassInstrumentView(label: "Heading", unit: "°", minimum: 0, maximum: 360, currentValue: 45)
}
