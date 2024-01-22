//
//  FlightRecorder.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-30.
//

import Foundation

class FlightRecorder: FlightRecorderService {
    
    init(
        currentFlight: Flight? = nil
    ) {
        self.currentFlight = currentFlight
    }
    
    var recording: Bool = false
    private var currentFlight: Flight?
    
    /// Starts recording a new flight
    func startRecording() {
        recording = true
        if currentFlight == nil {
            currentFlight = .init()
        }
    }
    
    /// Stops recording a flight and archives it
    func stopRecording() {
        recording = false
        #warning("TODO - Archive flight")
    }
    
    /// Stores a flight frame to the current flight
    func storeFrame(frame: FlightFrame) {
        if !recording {
            startRecording()
        }
        currentFlight?.flightFrames.append(frame)
    }
    
    /// Imports a .IGC file
    func importFlight() {
        #warning("TODO - Implementation")
    }
    
    /// Exports a .IGC file
    func exportFlight() {
        #warning("TODO - Implementation")
    }
    
    
}
