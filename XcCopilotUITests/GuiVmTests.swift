//
//  GuiVmTests.swift
//  XcCopilotUITests
//
//  Created by Dave Cameron on 2024-08-13.
//

import XCTest
@testable import XcCopilot

@MainActor
final class GuiVmTests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    override func tearDownWithError() throws {
        
    }
    
    @MainActor
    func testFlightState() {
        
        let app = XCUIApplication()
        app.tabBars["Tab Bar"].buttons["Instruments"].tap()
        let button = app.buttons["FlightStateButton"]
        
        XCTAssertEqual("Arm for Flight", button.label)
        button.tap()
        XCTAssertEqual("End Flight", button.label)
        button.tap()
        XCTAssertEqual("Arm for Flight", button.label)
    }
    
    @MainActor
    func testLogBook() {
        
        let app = XCUIApplication()
        app.tabBars["Tab Bar"].buttons["Logbook"].tap()
        
        let collectionViewsQuery2 = app.collectionViews
        let unknownFlightAugust14202400004Button = collectionViewsQuery2/*@START_MENU_TOKEN@*/.buttons["Unknown Flight, August 14, 2024, 0:00:04"]/*[[".cells.buttons[\"Unknown Flight, August 14, 2024, 0:00:04\"]",".buttons[\"Unknown Flight, August 14, 2024, 0:00:04\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        unknownFlightAugust14202400004Button.tap()
        app.navigationBars["Unknown Flight"].buttons["Logbook"].tap()
        unknownFlightAugust14202400004Button.tap()
        
        let collectionViewsQuery = collectionViewsQuery2
        collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["View Playback"]/*[[".cells",".buttons[\"View Playback\"].staticTexts[\"View Playback\"]",".staticTexts[\"View Playback\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Play"]/*[[".cells.buttons[\"Play\"]",".buttons[\"Play\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Pause"]/*[[".cells.buttons[\"Pause\"]",".buttons[\"Pause\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.sliders["5"]/*[[".cells.sliders[\"5\"]",".sliders[\"5\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeLeft()
        app.navigationBars["Flight Profile"].buttons["Unknown Flight"].tap()
        
        XCTAssertTrue(app.tabBars["Tab Bar"].exists)
    }
    
    @MainActor
    func testSettings() {
        
        let app = XCUIApplication()
        app.tabBars["Tab Bar"].buttons["Settings"].tap()
        
        let collectionViewsQuery = app.collectionViews
        collectionViewsQuery.textFields["Pilot: "].clearText()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.textFields["Pilot: "]/*[[".cells.textFields[\"Pilot: \"]",".textFields[\"Pilot: \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.textFields["Pilot: "]/*[[".cells.textFields[\"Pilot: \"]",".textFields[\"Pilot: \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeText("Jon Smith")
        collectionViewsQuery/*@START_MENU_TOKEN@*/.textFields["Glider: "]/*[[".cells.textFields[\"Glider: \"]",".textFields[\"Glider: \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.clearText()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.textFields["Glider: "]/*[[".cells.textFields[\"Glider: \"]",".textFields[\"Glider: \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.textFields["Glider: "]/*[[".cells.textFields[\"Glider: \"]",".textFields[\"Glider: \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeText("Ozone")
        app.collectionViews/*@START_MENU_TOKEN@*/.textFields["Trim Speed (km/h): "]/*[[".cells.textFields[\"Trim Speed (km\/h): \"]",".textFields[\"Trim Speed (km\/h): \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.clearText()
        app.collectionViews/*@START_MENU_TOKEN@*/.textFields["Trim Speed (km/h): "]/*[[".cells.textFields[\"Trim Speed (km\/h): \"]",".textFields[\"Trim Speed (km\/h): \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.collectionViews/*@START_MENU_TOKEN@*/.textFields["Trim Speed (km/h): "]/*[[".cells.textFields[\"Trim Speed (km\/h): \"]",".textFields[\"Trim Speed (km\/h): \"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeText("31")
        app.collectionViews/*@START_MENU_TOKEN@*/.sliders["volume"]/*[[".cells.sliders[\"volume\"]",".sliders[\"volume\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeLeft()
        
        XCTAssertTrue(app.tabBars["Tab Bar"].exists)
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

extension XCUIElement {
    /**
     Removes any current text in the field before typing in the new value
     - Parameter text: the text to enter into the field
     */
    func clearText() {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }
        
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
}
