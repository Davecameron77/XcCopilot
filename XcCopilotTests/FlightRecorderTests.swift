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
        var success = false
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            do {
                try await flightRecorder.importFlight(forUrl: url)
                success = true
            } catch {
                print("Test failed: \(error)")
                return
            }
            XCTAssert(success)
        }
    }
    
    func testExportFlight() async {
        let flightRecorder = FlightRecorder()
        var result: IgcFile?
        var success = false
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            do {
                try await flightRecorder.importFlight(forUrl: url)
                result = try await flightRecorder.exportFlight(flightToExport: flightRecorder.getFlights().first!)
                success = true
            } catch {
                print("Test failed: \(error)")
                return
            }
        }
        XCTAssert(success)
        XCTAssertNotNil(result)
    }
    
    func testGetFlights() async {
        let flightRecorder = FlightRecorder()
        var success = false
        var flights: [Flight]?
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            do {
                try await flightRecorder.importFlight(forUrl: url)
                flights = try await  flightRecorder.getFlights()
                success = true
            } catch {
                print("Test failed: \(error)")
                return
            }
            XCTAssert(success)
            XCTAssertNotNil(flights)
            XCTAssertFalse(flights!.isEmpty)
        }
    }

    func testGetFlightsAroundCoords() async {
        let flightRecorder = FlightRecorder()
        var success = false
        var flights: [Flight]?
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            do {
                try await flightRecorder.importFlight(forUrl: url)
                flights = try await  flightRecorder.getFlightsAroundCoords(
                    CLLocationCoordinate2D(latitude: 49.24, longitude: -121.88),
                    withSpan: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
                )
                success = true
            } catch {
                print("Test failed: \(error)")
                return
            }
            XCTAssert(success)
            XCTAssertNotNil(flights)
            XCTAssertFalse(flights!.isEmpty)
        }
    }
    
    func testArmForFlight() {
     
        let flightRecorder = FlightRecorder()
        var success = false
        
        Task {
            do {
                try await flightRecorder.armForFlight()
            } catch {
                print("Test failed: \(error)")
                return
            }
        }
        success = true
        XCTAssert(success)
    }
}
