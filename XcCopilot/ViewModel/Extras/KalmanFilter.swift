//
//  KalmanFilter.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-06-23.
//

import Foundation

class KalmanFilter {
    // Acceleration noise variance
    private var varianceXAccel: Double
    // Absolute position
    var xAbsolutePosition: Double
    // Absolute velocity
    var xAbsoluteVelocity: Double
    // Position variance
    private var positionVariance: Double
    // Position/Velocity Covariance
    private var positionVelocityCovariance: Double
    // Velocity variance
    private var velocityVariance: Double
    
    init(varXAccel: Double = 0.05) {
        self.varianceXAccel = varXAccel
        self.xAbsolutePosition = 0.0
        self.xAbsoluteVelocity = 0.0
        self.positionVariance = 1e6
        self.positionVelocityCovariance = 0.0
        self.velocityVariance = varXAccel
    }
    
    func reset(xAbsValue: Double = 0.0, xVelValue: Double = 0.0) {
        self.xAbsolutePosition = xAbsValue
        self.xAbsoluteVelocity = xVelValue
        self.positionVariance = 1e6
        self.positionVelocityCovariance = 0.0
        self.velocityVariance = varianceXAccel
    }
    
    func update(zAbs: Double, varZAbs: Double, dt: Double) {
        assert(dt > 0)
        
        // Predict step, update state est
        xAbsolutePosition += xAbsoluteVelocity * dt
        
        let dt2 = dt * dt
        let dt3 = dt * dt2
        let dt4 = dt2 * dt2
        positionVariance += 2 * dt * positionVelocityCovariance + dt2 * velocityVariance + varianceXAccel * dt4 / 4
        positionVelocityCovariance += dt * velocityVariance + varianceXAccel * dt3 / 2
        velocityVariance += varianceXAccel * dt2
        
        // Update step
        let y = zAbs - xAbsolutePosition // Innovation
        let sInv = 1 / (positionVariance + varZAbs) // Innovation precision
        let kAbs = positionVariance * sInv // Kalman gain
        let kVel = positionVelocityCovariance * sInv
        
        xAbsolutePosition += kAbs * y
        xAbsoluteVelocity += kVel * y
        
        velocityVariance -= positionVelocityCovariance * kVel
        positionVelocityCovariance -= positionVelocityCovariance * kAbs
        positionVariance -= positionVariance * kAbs
    }
}
