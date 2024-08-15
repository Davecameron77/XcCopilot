//
//  ViewModelTests.swift
//  XcCopilotTests
//
//  Created by Dave Cameron on 2024-08-13.
//

import MapKit
import XCTest
@testable import XcCopilot

final class ViewModelTests: XCTestCase {

    #warning("Migrate to GUI test")
    func testRecordingFlight() {
        let vm = XcCopilotViewModel()
        
        Task {
            try await vm.flightRecorder.deleteAllFlights()
            
            vm.armForFlight()
            vm.startFlying()
            sleep(3)
            vm.stopFlying()
            
            let flights = try await vm.getFlights()
            
            XCTAssertNotNil(flights)
            XCTAssertEqual(1, flights.count)
        }
    }
    
    #warning("Migrate to GUI test")
    func testGetWeather() {
        let vm = XcCopilotViewModel()
        vm.updateWeather()
        Task {
            sleep(2)
            XCTAssertNotNil(vm.currentWeather)
            print("Asserted weather")
        }
    }

    func testImportIgcFile() {
        
        let vm = XcCopilotViewModel()
        let bundle = Bundle(for: Self.self)
        
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            Task {
                try await vm.flightRecorder.deleteAllFlights()
                let result = await vm.importIgcFile(forUrl: url)
                let flights = try await vm.getFlights()
                
                XCTAssert(result)
                XCTAssert(!flights.isEmpty)
                XCTAssertEqual(1, flights.count)
            }
        }
    }
    
    func testExportIgcFile() {

        let vm = XcCopilotViewModel()
        let bundle = Bundle(for: Self.self)
        
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            Task {
                do {
                    try await vm.flightRecorder.deleteAllFlights()
                    let result = await vm.importIgcFile(forUrl: url)
                    XCTAssert(result)
                    
                    let flight = try await vm.getFlights().first!
                    let exportedFlight = await vm.exportIgcFile(flight: flight)
        
                    XCTAssertNotNil(exportedFlight)
                } catch {
                    print("Test Export Flight failed: \(error)")
                    return
                }
            }
        }
    }
    
    func testUpdateFlightTitle() {
        let vm = XcCopilotViewModel()
        let bundle = Bundle(for: Self.self)
        let newTitle = "New Title"
        
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            
            Task {
                do {
                    try await vm.flightRecorder.deleteAllFlights()
                    let result = await vm.importIgcFile(forUrl: url)
                    XCTAssert(result)
                    
                    let flight = try await vm.getFlights().first!
                    vm.updateFlightTitle(flightToUpdate: flight, withTitle: newTitle)
        
                    let updatedFlight = try await vm.getFlights().first!
                    XCTAssertEqual(updatedFlight.title, newTitle)
                    
                } catch {
                    print("Test Export Flight failed: \(error)")
                    return
                }
            }
        }
    }
    
    func testDeleteFlight() {
        
        let vm = XcCopilotViewModel()
        let bundle = Bundle(for: Self.self)
        
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            Task {
                try await vm.flightRecorder.deleteAllFlights()
                let result = await vm.importIgcFile(forUrl: url)
                XCTAssert(result)
                
                let flights = try await vm.getFlights()
                XCTAssert(!flights.isEmpty)
                XCTAssertEqual(1, flights.count)
                
                vm.deleteFlight(flights.first!)
                let flightsEmpty = try await vm.getFlights()
                XCTAssert(flightsEmpty.isEmpty)
            }
        }
    }
    
    func testAnalyzeFlights() {
        
        let vm = XcCopilotViewModel()
        let bundle = Bundle(for: Self.self)
        
        if let filePath = bundle.path(forResource: "test_igc", ofType: "IGC") {
            let url = URL(fileURLWithPath: filePath)
            Task {
                try await vm.flightRecorder.deleteAllFlights()
                let result = await vm.importIgcFile(forUrl: url)
                XCTAssert(result)
                
                let flights = try await vm.getFlights()
                XCTAssert(!flights.isEmpty)
                XCTAssertEqual(1, flights.count)
                
                let coords = CLLocationCoordinate2D(latitude: flights.first!.launchLatitude, longitude: flights.first!.launchLongitude)
                let span = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                let quadtree = vm.analyzeFlights(flights, aroundCoords: coords, withinSpan: span)
                XCTAssertNotNil(quadtree)
            }
        }
    }
}
