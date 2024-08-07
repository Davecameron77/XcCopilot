//
//  Extensions.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-18.
//

import SwiftUI
import MapKit
import SwiftData

extension CLLocationCoordinate2D {
    static var myLocation: CLLocationCoordinate2D {
        return .init(latitude: 49.24348,
                     longitude: -121.88751)
    }
    
    func coordinateToDMS() -> String {
        let latDms = toDms(dms: latitude)
        let lonDms = toDms(dms: longitude)

        let format = "%02d%02d%03d%@" + "%03d%02d%03d%@"
        return String(format: format, latDms.0, latDms.1, latDms.2, latitude >= 0 ? "N" : "S",
                      lonDms.0, lonDms.1, lonDms.2, longitude >= 0 ? "E" : "W")
    }
    
    func latitudeToDMS() -> (Int, Int, Int) {
        return toDms(dms: latitude)
    }
    
    func longitudeToDMS() -> (Int, Int, Int) {
        return toDms(dms: longitude)
    }
    
    private func toDms(dms: Double) -> (Int, Int, Int) {
        let degrees = abs(Int(dms))
        let minutes = Int((abs(dms) - abs(dms.rounded(.towardZero))) * 60)
        let seconds = Int(((abs(dms) - abs(dms.rounded(.towardZero)) - (Double(minutes)/60.0)) * 3600).rounded(.toNearestOrAwayFromZero))
        return (deg:degrees, min:minutes, sec:seconds)
    }
}

extension MKCoordinateSpan {
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
}

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
    
    func get(_ components: Calendar.Component..., calendar: Calendar = Calendar.current) -> DateComponents {
        return calendar.dateComponents(Set(components), from: self)
    }

    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        return calendar.component(component, from: self)
    }
}

extension Array where Element: BinaryInteger {

    /// The average value of all the items in the array
    var average: Double {
        if self.isEmpty {
            return 0.0
        } else {
            let sum = self.reduce(0, +)
            return Double(sum) / Double(self.count)
        }
    }

}

extension Array where Element: BinaryFloatingPoint {

    /// The average value of all the items in the array
    var average: Double {
        if self.isEmpty {
            return 0.0
        } else {
            let sum = self.reduce(0, +)
            return Double(sum) / Double(self.count)
        }
    }

    func simpleMovingAverage() -> Double where Element == Double {
        guard self.count >= 1 else { return 0.0 }
        
        let size = self.count
        var sum = 0.0
        
        for i in 0..<self.count-1 {
            sum += self[i+1] - self[i]
        }
        
        return sum / Double(size)
    }
    
    func effectiveMovingAverage() -> Double where Element == Double {
        guard self.count >= 3 else { return 0.0 }
        
        let size = self.count - 1
        var sum = 0.0
        let ascending = self.last ?? 0.0 > 0.0
        
        for index in stride(from: size, through: 1, by: -1) {
            if ascending && self[index] < 0.0 { break }
            if !ascending && self[index] > 0.0 { break }
            
            sum += self[index-1] + self[index]
        }
        
        return sum / Double(size)
    }
}

extension String {
    func subString(from: Int, to: Int) -> String {
       let startIndex = self.index(self.startIndex, offsetBy: from)
       let endIndex = self.index(self.startIndex, offsetBy: to)
       
        return String(self[startIndex..<endIndex])
    }
    
    mutating func addNewLine() {
        self.write("\r\n")
    }
}

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var degreesToRadians: Double { self * .pi / 180 }
    
    func toDegreesMinutesSeconds() -> (Int, Int, Int) {
        let degrees = Int(self)
        let fractionalDegrees = abs(self - Double(degrees))
        let minutes = Int(fractionalDegrees * 60)
        let seconds = Int((fractionalDegrees * 60 - Double(minutes)) * 60)
        
        return (degrees, minutes, seconds)
    }
}

extension TimeInterval {
    var hourMinuteSecond: String {
        String(format:"%d:%02d:%02d", hour, minute, second, millisecond)
    }
    var minuteSecondMS: String {
        String(format:"%d:%02d.%03d", minute, second, millisecond)
    }
    var hour: Int {
        Int((self/3600).truncatingRemainder(dividingBy: 3600))
    }
    var minute: Int {
        Int((self/60).truncatingRemainder(dividingBy: 60))
    }
    var second: Int {
        Int(truncatingRemainder(dividingBy: 60))
    }
    var millisecond: Int {
        Int((self*1000).truncatingRemainder(dividingBy: 1000))
    }
}

enum DataError: Error {
    case invalidData(String)
}

struct HashableNode: Hashable, Identifiable {
    var id = UUID().uuidString
    let timestamp: Date
    var interval: Duration?
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let verticalSpeed: Double
    let derrivedVerticalSpeed: Double
}

struct MapMark: Hashable, Identifiable {
    
    let id = UUID()
    let coords: CLLocationCoordinate2D
    let altitude: Double
    let verticalSpeed: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MapMark, rhs: MapMark) -> Bool {
        return lhs.id == rhs.id
    }
}

extension MKCoordinateRegion {
    
    var boundingBoxCoordinates: [String: CLLocationCoordinate2D] {
        let halfLatDelta = self.span.latitudeDelta / 2
        let halfLngDelta = self.span.longitudeDelta / 2

        let topLeft = CLLocationCoordinate2D(
            latitude: self.center.latitude + halfLatDelta,
            longitude: self.center.longitude - halfLngDelta
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: self.center.latitude - halfLatDelta,
            longitude: self.center.longitude + halfLngDelta
        )
        let bottomLeft = CLLocationCoordinate2D(
            latitude: self.center.latitude - halfLatDelta,
            longitude: self.center.longitude - halfLngDelta
        )
        let topRight = CLLocationCoordinate2D(
            latitude: self.center.latitude + halfLatDelta,
            longitude: self.center.longitude + halfLngDelta
        )

        return [
            "topLeft": topLeft,
            "topRight": topRight,
            "bottomRight": bottomRight,
            "bottomLeft": bottomLeft
        ]
    }
    
    
    func contains(coords: CLLocationCoordinate2D) -> Bool {
        let topLat = self.center.latitude + 0.5 * self.span.latitudeDelta
        let bottomLat = self.center.latitude - 0.5 * self.span.latitudeDelta
        let leftLong = self.center.longitude - 0.5 * self.span.longitudeDelta
        let rightLong = self.center.longitude + 0.5 * self.span.longitudeDelta
        
        if (coords.latitude  <= topLat && coords.latitude >= bottomLat &&
            coords.longitude >= leftLong && coords.longitude <= rightLong) {
            return true
        } else {
            return false
        }
    }
 
    func intersects(searchRegion: MKCoordinateRegion) -> Bool {
        let coords = self.boundingBoxCoordinates
        for coord in coords {
            if self.contains(coords: coord.value) {
                return true
            }
        }
        return false
    }
}

struct MyCoordinateRegion: Hashable {
    var region: MKCoordinateRegion
    var count = 0
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(region.center.latitude + region.center.longitude)
    }
    
    static func == (lhs: MyCoordinateRegion, rhs: MyCoordinateRegion) -> Bool {
        return lhs.region.center.latitude == rhs.region.center.latitude &&
               lhs.region.center.longitude == rhs.region.center.longitude
    }
}
