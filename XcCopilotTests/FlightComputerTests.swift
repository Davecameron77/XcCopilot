//
//  FlightComputerTests.swift
//  XcCopilotTests
//
//  Created by Dave Cameron on 2024-08-06.
//

import XCTest
@testable import XcCopilot

final class FlightComputerTests: XCTestCase {

    ///
    /// Tests the call to start a flight
    ///
    func testStartFlight() {
        let flightComputer = FlightComputer()
        
        XCTAssertFalse(flightComputer.inFlight)
        XCTAssertNil(flightComputer.launchTimeStamp)
        
        do {
            try flightComputer.startFlying()
        } catch  {
            print("Error testing start flight: \(error)")
        }

        XCTAssertTrue(flightComputer.inFlight)
        XCTAssertNotNil(flightComputer.launchTimeStamp)
    }
    
    ///
    /// Tests the call to stop a flight
    ///
    func testStopFlight() {
        let flightComputer = FlightComputer()
        
        XCTAssertFalse(flightComputer.inFlight)
        XCTAssertNil(flightComputer.launchTimeStamp)
        
        do {
            try flightComputer.startFlying()
            XCTAssert(flightComputer.inFlight)
            XCTAssertNotNil(flightComputer.launchTimeStamp)
            flightComputer.stopFlying()
        } catch {
            print("Error testing stop flight: \(error)")
        }
        
        XCTAssertFalse(flightComputer.inFlight)
        XCTAssertNil(flightComputer.launchTimeStamp)
    }
    
    ///
    /// Tests that the run loop generates simulated values
    ///
    func testRunLoop() {
        let flightComputer = FlightComputer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            XCTAssert(flightComputer.gpsSpeed != 0)
            XCTAssert(flightComputer.gpsCourse != 0)
            XCTAssert(flightComputer.magneticHeading != 0)
            XCTAssertNotNil(flightComputer.currentCoords)
            XCTAssertNotNil(flightComputer.acceleration)
            XCTAssertNotNil(flightComputer.gravity)
        }
    }

    ///
    /// Tests elevation calculation
    /// Given the sim has a variable bike path simulated, an exact value cannot be known
    ///
    func testCalculateElevation() {
        let flightComputer = FlightComputer()
        flightComputer.baroAltitude = 300.00
        
        Task {
            sleep(1)
            await flightComputer.calculateElevation()
            XCTAssert(flightComputer.terrainElevation > 0.0)
            XCTAssert(flightComputer.calculatedElevation > 0.0)
        }
    }
}
