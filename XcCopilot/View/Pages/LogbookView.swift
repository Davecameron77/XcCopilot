//
//  LogbookView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LogbookView: View {
    @EnvironmentObject var vm: XcCopilotViewModel
    @Environment(\.modelContext) var context
    @Query(sort: \Flight.flightStartDate, order: .reverse) var flights: [Flight]
    
    @State private var importerShowing = false
    
    let igcType = UTType(exportedAs: "ca.tinyweb.xccopilot.igc")
    private let formatter = DateComponentsFormatter()
        
    var body: some View {
        NavigationView {
            VStack {
                Button("Import Flight") {
                    importerShowing = true
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .padding()
                .fileImporter(
                    isPresented: $importerShowing, allowedContentTypes: [.item]) { result in
                        switch result {
                        case .success(let url):
                            importFlight(forUrl: url)
                        case .failure(let error):
                            print(error)
                        }
                    }
                
                List {
                    ForEach(flights) { flight in
                        @Bindable var flight = flight
                        NavigationLink {
                            FlightView(flight: flight)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(flight.flightTitle)
                                    .font(.title2)
                                HStack {
                                    Text(flight.flightStartDate, style: .date)
                                    Spacer()
                                    Text(flight.flightDuration)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteFlight)
                    .onMove { vm.logbook.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset)
                .navigationTitle("Logbook")
                .toolbar {
                    EditButton()
                }

            }
        }
    }
    
    func importFlight(forUrl url: URL) {
        Task { @MainActor in
            if url.startAccessingSecurityScopedResource() {
                if let flight = await vm.importIgcFile(forUrl: url) {
                    context.insert(flight)
                } else {
                    vm.showAlert(withText: "Error importing flight")
                }
            }
        }
    }
    
    func deleteFlight(_ indexSet: IndexSet) {
        for index in indexSet {
            let flight = flights[index]
            context.delete(flight)
        }
    }
}

#Preview {
    LogbookView()
        .environmentObject(XcCopilotViewModel())
}
