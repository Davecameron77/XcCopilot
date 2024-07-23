//
//  Enums.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-18.
//

import Foundation

enum FlightState: CaseIterable {
    case landed
    case armed
    case inFlight
}

enum SpeedUnits: String, CaseIterable, Codable {
    case kmh = "km/h"
    case mph = "mph"
    case knot = "kt"
    case mps = "m/s"
}

enum ElevationUnits: String, CaseIterable, Codable {
    case metres = "metres"
    case feet = "feet"
}

enum VerticalSpeedUnits: String, CaseIterable, Codable {
    case mps = "m/s"
    case fpm = "fpm"
}

enum TemperatureUnits: String, CaseIterable, Codable {
    case c = "c"
    case f = "f"
}

enum VolumeLevels: Int, Equatable, CaseIterable {
    case off = 0
    case ten = 10
    case twenty = 20
    case thirty = 30
    case fourty = 40
    case fifty = 50
    case sixty = 60
    case seventy = 70
    case eighty = 80
    case ninety = 90
    case max = 100
    
    static func ==(lhs: VolumeLevels, rhs: VolumeLevels) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

enum HRecord: String {   
    case HFDTE, HFFXA, HFPLT, HFCM2, HFGTY, HFGID, HFDTM, HFRFW, HFRHW, HFFTY, HFGPS, HFPRS, HFCID, HFCCL, HFSIT
    
    var description: LocalizedStringResource {
        switch self {
        case .HFDTE:
            "HFDTE"
        case .HFFXA:
            "HFFXA"
        case .HFPLT:
            "HFPLT"
        case .HFCM2:
            "HFCM2"
        case .HFGTY:
            "HFGTY"
        case .HFGID:
            "HFGID"
        case .HFDTM:
            "HFDTM"
        case .HFRFW:
            "HFRFW"
        case .HFFTY:
            "HFFTY"
        case .HFRHW:
            "HFRHW"
        case .HFGPS:
            "HFGPS"
        case .HFPRS:
            "HFPRS"
        case .HFCID:
            "HFCID"
        case .HFCCL:
            "HFCCL"
        case .HFSIT:
            "HFSIT"
        }
    }
}
