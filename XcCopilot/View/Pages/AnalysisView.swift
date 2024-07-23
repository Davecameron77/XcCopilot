//
//  AnalysisView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-13.
//

import CoreML
import MapKit
import SwiftUI

struct AnalysisView: View {
    @Namespace var mapScope
    @EnvironmentObject var vm: XcCopilotViewModel
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 49.2357,
                                                          longitude: -121.9),
                           span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    
    @State private var topLeft = CLLocationCoordinate2D(latitude: 49.2357, longitude: -121.9)
    @State private var bottomRight = CLLocationCoordinate2D(latitude: 49.2357, longitude: -121.9)
    @State private var searchResults: [MapMark] = []
    
    var body: some View {
        Map(position: $position, interactionModes: .all, scope: mapScope) {
            ForEach(searchResults) { result in
                MapCircle(center: result.coords, radius: 1000)
                    .foregroundStyle(.red)
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView(anchorEdge: .trailing)
        }
        .safeAreaInset(edge: .bottom, content: {
            Button {
                analyzeFlights()
            } label: {
                Text("Analyze")
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
        })
        .onAppear {
            let center = position.region?.center
            let latDelta = position.region?.span.latitudeDelta
            let longDelta = position.region?.span.longitudeDelta
            
            let topLat = center!.latitude + 0.5 * latDelta!
            let bottomLat = center!.latitude - 0.5 * latDelta!
            let leftLong = center!.longitude - 0.5 * longDelta!
            let rightLong = center!.longitude + 0.5 * longDelta!
            
            topLeft = CLLocationCoordinate2D(latitude: topLat, longitude: leftLong)
            bottomRight = CLLocationCoordinate2D(latitude: bottomLat, longitude: rightLong)
        }
        .onMapCameraChange { mapContext in
            let center = mapContext.camera.centerCoordinate
            let latDelta = mapContext.region.span.latitudeDelta
            let longDelta = mapContext.region.span.longitudeDelta
            
            let topLat = center.latitude + 0.5 * latDelta
            let bottomLat = center.latitude - 0.5 * latDelta
            let leftLong = center.longitude - 0.5 * longDelta
            let rightLong = center.longitude + 0.5 * longDelta
            
            topLeft = CLLocationCoordinate2D(latitude: topLat, longitude: leftLong)
            bottomRight = CLLocationCoordinate2D(latitude: bottomLat, longitude: rightLong)
        }
    }
    
    func analyzeFlights() {
        do {
            let config = MLModelConfiguration()
            let model = try thermal_predictor(configuration: config)
            
            Task(priority: .medium) {
                let topLeftLatitudeDms = topLeft.latitudeToDMS()
                let topLeftLongitudeDms = topLeft.longitudeToDMS()
                let bottomRightLatitudeDms = bottomRight.latitudeToDMS()
                let bottomRightLongitudeDms = bottomRight.longitudeToDMS()
                
                let latDegreesTo = topLeftLatitudeDms.0 > bottomRightLatitudeDms.0 ? topLeftLatitudeDms.0 : bottomRightLatitudeDms.0
                let latMinutesTo = topLeftLatitudeDms.1 > bottomRightLatitudeDms.1 ? topLeftLatitudeDms.1 : bottomRightLatitudeDms.1
                let latDegreesFrom = topLeftLatitudeDms.0 < bottomRightLatitudeDms.0 ? topLeftLatitudeDms.0 : topLeftLatitudeDms.0
                let latMinutesFrom = topLeftLatitudeDms.1 < bottomRightLatitudeDms.1 ? topLeftLatitudeDms.1 : topLeftLatitudeDms.1
                
                let longDegreesTo = topLeftLongitudeDms.0 > bottomRightLongitudeDms.0 ? topLeftLongitudeDms.0 : bottomRightLongitudeDms.0
                let longMinutesTo = topLeftLongitudeDms.1 > bottomRightLongitudeDms.1 ? topLeftLongitudeDms.1 : bottomRightLongitudeDms.1
                let longDegreesFrom = topLeftLongitudeDms.0 < bottomRightLongitudeDms.0 ? topLeftLongitudeDms.0 : bottomRightLongitudeDms.0
                let longMinutesFrom = topLeftLongitudeDms.1 < bottomRightLongitudeDms.1 ? topLeftLongitudeDms.1 : bottomRightLongitudeDms.1
                
                searchResults.removeAll()
                
                for latDegree in latDegreesFrom...latDegreesTo {
                    for latMinute in latMinutesFrom...latMinutesTo {
                        for longDegree in longDegreesFrom...longDegreesTo {
                            for longMinute in longMinutesFrom...longMinutesTo {
                                let result = try model.prediction(
                                    ZLATITUDEDEGREES: Int64(latDegree),
                                    ZLATITUDEMINUTES: Int64(latMinute),
                                    ZLATITUDESECONDS: 0,
                                    ZLONGITUDEDEGREES: Int64(longDegree),
                                    ZLONGITUDEMINUTES: Int64(longMinute),
                                    ZLONGITUDESECONDS: 0)
                                
                                print("Searching Lat: \(latDegree).\(latMinute) | Lng: \(longDegree).\(longMinute) - \(result.ZVERTICALSPEED)")
                                if result.ZVERTICALSPEED > 0.0 {
                                    let latitude = dmsToDecimal(degrees: topLeftLatitudeDms.0, minutes: latMinute, seconds: 0, direction: (topLeftLatitudeDms.0 > 0 ? "N" : "S"))
                                    let longitude = dmsToDecimal(degrees: topLeftLongitudeDms.0, minutes: longMinute, seconds: 0, direction: (topLeftLongitudeDms.0 > 0 ? "E" : "W"))
                                    
                                    searchResults.append(MapMark(coords: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
                                }
                            }
                        }
                    }
                }
                for result in searchResults {
                    print("\(result.coords.latitude) : \(result.coords.longitude)")
                }
            }
        } catch {
            vm.showAlert(withText: "CoreML error: \(error)")
        }
    }
    
    func dmsToDecimal(degrees: Int, minutes: Int, seconds: Double, direction: String) -> Double {
        var decimalDegrees = Double(degrees) + Double(minutes) / 60.0 + seconds / 3600.0
        
        if direction == "S" || direction == "W" {
            decimalDegrees *= -1
        }
        
        return decimalDegrees
    }
}

struct MapMark: Identifiable {
    let id = UUID()
    let coords: CLLocationCoordinate2D
    let altitude: Double = 0.0
    let verticalSpeed: Double = 0.0
}

//#Preview {
//    AnalysisView()
//        .environmentObject(XcCopilotViewModel())
//}
