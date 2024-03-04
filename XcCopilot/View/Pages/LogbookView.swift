//
//  LogbookView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI
import UniformTypeIdentifiers

struct LogbookView: View {
    @EnvironmentObject var vm: XcCopilotViewModel
    @Environment(\.modelContext) var context
    
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
                    isPresented: $importerShowing,
                    allowedContentTypes: [.item]) { result in
                        
                        switch result {
                        case .success(let url):
                            Task {
                                if url.startAccessingSecurityScopedResource() {
                                    if let flight = await vm.importIgcFile(forUrl: url) {
                                        context.insert(flight)
                                    } else {
                                        vm.showAlert(withText: "Error importing flight")
                                    }
                                }
                            }
                        case .failure(let error):
                            print(error)
                        }
                    }
                
                List {
                    ForEach(vm.logbook) { flight in
                        NavigationLink {
                            FlightView(flight: flight)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(flight.flightTitle)
                                    .font(.title2)
                                HStack {
                                    Text(flight.flightStartDate, style: .date)
                                    Spacer()
                                    Text(formatter.string(from: flight.flightDuration)!)
                                }
                            }
                        }
                    }
                    .onDelete { vm.logbook.remove(atOffsets: $0) }
                    .onMove { vm.logbook.move(fromOffsets: $0, toOffset: $1) }
                }
                .navigationTitle("Logbook")
                .toolbar {
                    EditButton()
                }

            }
        }
    }
}

#Preview {
    LogbookView()
        .environmentObject(XcCopilotViewModel())
}
