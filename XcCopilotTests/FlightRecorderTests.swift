//
//  FlightRecorderTests.swift
//  XcCopilotTests
//
//  Created by Dave Cameron on 2024-08-06.
//

import MapKit
import XCTest
@testable import XcCopilot

final class FlightRecorderTests: XCTestCase {
            
    func testImportFlight() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            do {
                try await flightRecorder.deleteAllFlights()
                try await flightRecorder.importFlight(forUrl: url)
                let flights = try await flightRecorder.getFlights()
                print("Asserting flight count \(flights.count)")
                XCTAssert(!flights.isEmpty)
                XCTAssertEqual(1, flights.count)
                XCTAssert(flights.first!.duration != nil)
            } catch {
                print("Fuckberries: \(error)")
            }            
        }
    }
    
    func testExportFlight() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            Task {
                do {
                    try await flightRecorder.deleteAllFlights()
                    try await flightRecorder.importFlight(forUrl: url)
                    let result = try await flightRecorder.exportFlight(flightToExport: flightRecorder.getFlights().first!)
                    XCTAssertNotNil(result)
                } catch {
                    print("Test Export Flight failed: \(error)")
                    return
                }
            }
        }
    }
    
    func testGetFlights() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            Task {
                do {
                    try await flightRecorder.deleteAllFlights()
                    try await flightRecorder.importFlight(forUrl: url)
                    let flights = try await  flightRecorder.getFlights()
                    XCTAssertNotNil(flights)
                    XCTAssertFalse(flights.isEmpty)
                } catch {
                    print("Test failed: \(error)")
                    return
                }
            }
        }
    }

    func testGetFlightsAroundCoords() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            Task {
                do {
                    try await flightRecorder.deleteAllFlights()
                    try await flightRecorder.importFlight(forUrl: url)
                    let flights = try await  flightRecorder.getFlightsAroundCoords(
                        CLLocationCoordinate2D(latitude: 49.24, longitude: -121.88),
                        withSpan: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
                    )
                    XCTAssertNotNil(flights)
                    XCTAssertFalse(flights.isEmpty)
                } catch {
                    print("Test failed: \(error)")
                    return
                }
            }
        }
    }
    
    func testArmForFlight() {
        let flightRecorder = FlightRecorder()
        
        Task {
            do {
                try await flightRecorder.deleteAllFlights()
                try await flightRecorder.armForFlight()
                let flight = await flightRecorder.flight
                XCTAssertNotNil(flight)
            } catch {
                print("Test failed: \(error)")
                return
            }
        }
    }
}
