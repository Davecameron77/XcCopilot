//
//  FlightComputerTests.swift
//  XcCopilotTests
//
//  Created by Dave Cameron on 2024-08-06.
//

import XCTest
@testable import XcCopilot

final class FlightComputerTests: XCTestCase {

    func testStartFlight() {
        let flightComputer = FlightComputer()
        
        do {
            try flightComputer.startFlying()
        } catch  {
            print("Error testing start flight: \(error)")
        }
                
        XCTAssertTrue(flightComputer.inFlight)
        XCTAssertNotNil(flightComputer.launchTimeStamp)
    }
    
    func testStopFlight() {
        let flightComputer = FlightComputer()
        
        do {
            try flightComputer.startFlying()
            flightComputer.stopFlying()
        } catch {
            print("Error testing stop flight: \(error)")
        }
        
        XCTAssertFalse(flightComputer.inFlight)
        XCTAssertNil(flightComputer.launchTimeStamp)
    }
    
    func testVerticalVelocity() {
        let flightComputer = FlightComputer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            print(flightComputer.gpsSpeed)
            XCTAssert(flightComputer.gpsSpeed != 0)
            XCTAssert(flightComputer.gpsCourse != 0)
            XCTAssert(flightComputer.magneticHeading != 0)
            XCTAssertNotNil(flightComputer.currentCoords)
            XCTAssertNotNil(flightComputer.acceleration)
            XCTAssertNotNil(flightComputer.gravity)
            XCTAssert(flightComputer.verticalVelocityMps != 0)
        }
    }

}
