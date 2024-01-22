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
    var trimSpeed: Double
    
    init(name: String, trimSpeed: Double) {
        self.name = name
        self.trimSpeed = trimSpeed
    }
}
