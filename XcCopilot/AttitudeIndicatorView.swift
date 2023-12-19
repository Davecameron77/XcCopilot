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
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
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
                                .offset(y: yaw)
                        }
                    }
                    
                    VStack {
                        Gauge(value: pitch, in: -90...90) {
                            Text("Pitch")
                        } currentValueLabel: {
                            Text("\(String(format: "%.1f", pitch))°")
                        } minimumValueLabel: {
                            Text("-90°")
                        } maximumValueLabel: {
                            Text("90°")
                        }

                        Gauge(value: roll, in: -180...180) {
                            Text("Roll")
                        } currentValueLabel: {
                            Text("\(String(format: "%.1f", roll))°")
                        } minimumValueLabel: {
                            Text("-180°")
                        } maximumValueLabel: {
                            Text("180°")
                        }
                        
                        Gauge(value: yaw, in: -90...90) {
                            Text("yaw")
                        } currentValueLabel: {
                            Text("\(String(format: "%.1f", yaw))°")
                        } minimumValueLabel: {
                            Text("-90°")
                        } maximumValueLabel: {
                            Text("90°")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    AttitudeIndicatorView(pitch: 0, roll: 0, yaw: 0)
}
