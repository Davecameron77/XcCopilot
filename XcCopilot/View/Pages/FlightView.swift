//
//  FlightView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-18.
//

import SwiftUI

struct FlightView: View {
    let flight: Flight
    private let formatter = DateComponentsFormatter()
    
    var body: some View {
        List {
            Text("Flight Start: \(flight.flightStartDate, format: .dateTime)")
            Text("Flight End: \(flight.flightStartDate, format: .dateTime)")
            Text("Flight Duration: \(formatter.string(from: flight.flightDuration)!)")
        }
        .navigationTitle(flight.flightTitle)
    }
}

#Preview {
    FlightView(flight: Flight.dummyFlight)
}
