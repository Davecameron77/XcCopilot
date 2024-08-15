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
        
    }
    
    func testStartFlying() {
        
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
