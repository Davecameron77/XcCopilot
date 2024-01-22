//
//  FlightRecorderService.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import Foundation

protocol FlightRecorderService {
    var recording: Bool { get set }
    
    func startRecording()
    func stopRecording()
    func storeFrame(frame: FlightFrame)
    func importFlight()
    func exportFlight()
}

