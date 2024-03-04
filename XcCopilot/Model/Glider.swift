//
//  Glider.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-21.
//

import Foundation
import SwiftData

@Model
class Glider {
    var name: String
    var trimSpeed: Double = 34.0
    var registration: String?
    
    init() {
        self.name = "Unknown Glider"
    }
    
    init(name: String?, trimSpeed: Double) {
        self.name = name ?? "Unknown Glider"
        self.trimSpeed = trimSpeed
    }
}
