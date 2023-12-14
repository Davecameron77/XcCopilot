//
//  AttitudeIndicatorView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-10.
//

import SwiftUI
import CoreMotion

struct AttitudeIndicatorView: View {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let gravity: CMAcceleration
    let acceleration: CMAcceleration
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.blue)
                            .frame(width: geometry.size.width*0.9, height: geometry.size.width*0.5)
                        Rectangle()
                            .fill(.brown)
                            .frame(width: geometry.size.width*0.9, height: geometry.size.width*0.5)
                    }
                    .clipShape(Circle())
                    .cornerRadius(10.0)
                    .padding()
                    
                    withAnimation(.linear) {
                        Rectangle()
                            .fill(.black)
                            .frame(width: geometry.size.width*0.85, height: 10)
                            .cornerRadius(10)
                            .rotationEffect(Angle(degrees: roll))
                            .offset(x: pitch, y: yaw)
                    }
                }
                
                VStack {
                    Gauge(value: gravity.x) {
                        Text("Gravity X: \(String(format: "%.0f", gravity.x*9.80665)) m/s²")
                    }
                    Gauge(value: acceleration.x) {
                        Text("Acceleration X: \(String(format: "%.0f", acceleration.x*9.80665)) m/s²")
                    }
                    Gauge(value: gravity.y) {
                        Text("Gravity Y: \(String(format: "%.0f", gravity.y*9.80665)) m/s²")
                    }
                    Gauge(value: acceleration.y) {
                        Text("Acceleration Y: \(String(format: "%.0f", acceleration.y*9.80665)) m/s²")
                    }
                    Gauge(value: gravity.z) {
                        Text("Gravity Z: \(String(format: "%.0f", gravity.z*9.80665)) m/s²")
                    }
                    Gauge(value: acceleration.z) {
                        Text("Acceleration Z: \(String(format: "%.0f", acceleration.z*9.80665)) m/s²")
                    }
                }
                .padding()
                
            }
        }
    }
}

#Preview {
    AttitudeIndicatorView(pitch: 10, roll: 15, yaw: 0, gravity: .init(x: 0, y: 0, z: 0), acceleration: .init(x: 0.5, y: 0.75, z: 1.0))
}
