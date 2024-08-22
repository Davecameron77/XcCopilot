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
    private let formatter = DateComponentsFormatter()
    
    @EnvironmentObject var vm: XcCopilotViewModel
    @State private var flights: [Flight] = []
    @State private var importerShowing = false
    @State private var exporterShowing = false
    @State private var selectedUrl: URL?
    
    var body: some View {
        NavigationStack {
            Section {
                if flights.isEmpty {
                    ContentUnavailableView("No flights",
                                           systemImage: "airplane.departure",
                                           description: Text("No flights stored/imported"))
                } else {
                    List {
                        ForEach(flights) { flight in
                            NavigationLink(value: flight) {
                                FlightCard(flight: flight)
                            }
                        }
                        .onDelete(perform: deleteFlight)
                    }
                }
            }
            .navigationTitle("Logbook")
            .navigationDestination(for: Flight.self) { flight in
                FlightView(flight: flight)
                    .environmentObject(vm)
            }
            .refreshable {
                getFlights()
            }
            .onAppear {
                getFlights()
            }
            .toolbar {
                Button("Import") {
                    importerShowing = true
                }
                EditButton()
            }
            .fileImporter(isPresented: $importerShowing,
                          allowedContentTypes: [UTType.igcType, UTType.text, UTType.plainText, .item]) { result in
                switch result {
                case .success(let url):
                    importFlight(forUrl: url)
                case .failure(let error):
                    vm.showAlert(withText: "Error importing flight: \(error)")
                }
            }
        }
    }
}

extension LogbookView {
    func getFlights() {
        Task {
            do {
                self.flights = try await vm.getFlights()
            } catch {
                vm.showAlert(withText: "Error getting logged flights")
            }
        }
    }
    
    func importFlight(forUrl url: URL) {
        Task(priority: .medium) {
            if url.startAccessingSecurityScopedResource() {
                if await vm.importIgcFile(forUrl: url) {
                    self.flights = try await vm.getFlights()
                }
            }
        }
    }
    
    func deleteFlight(at offsets: IndexSet) {
        vm.deleteFlight(flights[offsets.first!])
        getFlights()
    }
}


#Preview {
    LogbookView()
        .environmentObject(XcCopilotViewModel())
}
