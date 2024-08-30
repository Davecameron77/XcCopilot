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
    
    override class func setUp() {
        CoreDataManager.inMemory = true
    }
    
    override class func tearDown() {
        CoreDataManager.inMemory = false
    }
            
    func testImportFlight() async {

        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            try? flightRecorder.deleteAllFlights()
            try? await flightRecorder.importFlight(forUrl: url)
            sleep(2)
            let flights = try? flightRecorder.getFlights()
            
            XCTAssertNotNil(flights)
            XCTAssert(!flights!.isEmpty)
            XCTAssertNotNil(flights!.first)
            XCTAssert(flights!.first?.duration != nil)
            

        }
    }
    
    func testExportFlight() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            try? flightRecorder.deleteAllFlights()
            try? await flightRecorder.importFlight(forUrl: url)
            sleep(2)
            let result = try? await flightRecorder.exportFlight(flightToExport: flightRecorder.getFlights().first!)
            XCTAssertNotNil(result)
        }
    }
    
    func testGetFlights() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            try? flightRecorder.deleteAllFlights()
            try? await flightRecorder.importFlight(forUrl: url)
            sleep(2)
            let flights = try? flightRecorder.getFlights()
            
            XCTAssertNotNil(flights)
            XCTAssertFalse(flights!.isEmpty)
        }
    }

    func testGetFlightsAroundCoords() async {
        let flightRecorder = FlightRecorder()
        
        let bundle = Bundle(for: Self.self)
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            try? flightRecorder.deleteAllFlights()
            try? await flightRecorder.importFlight(forUrl: url)
            sleep(2)
            let flights = try? flightRecorder.getFlightsAroundCoords(
                CLLocationCoordinate2D(latitude: 49.24, longitude: -121.88),
                withSpan: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
            
            XCTAssertNotNil(flights)
            XCTAssertFalse(flights!.isEmpty)
        }
    }
    
    func testArmForFlight() async {
        let flightRecorder = FlightRecorder()
        
        try? flightRecorder.deleteAllFlights()
        try? flightRecorder.armForFlight()
        let flight = flightRecorder.flight
        
        XCTAssertNotNil(flight)
    }
}
