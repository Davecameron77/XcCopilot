//
//  Extensions.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-18.
//

import SwiftUI
import MapKit

struct InstrumentBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(minWidth: 75, idealWidth: 125, maxWidth: 125, minHeight: 75, idealHeight: 125, maxHeight: 125)
            .aspectRatio(contentMode: .fit)
            .background(Color(UIColor.systemBackground))
            .opacity(0.65)
            .cornerRadius(10)
    }
}

extension CLLocationCoordinate2D {
    static var myLocation: CLLocationCoordinate2D {
        return .init(latitude: 49.24348,
                     longitude: -121.88751)
    }
}

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
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

}

extension String {
    func subString(from: Int, to: Int) -> String {
       let startIndex = self.index(self.startIndex, offsetBy: from)
       let endIndex = self.index(self.startIndex, offsetBy: to)
       return String(self[startIndex..<endIndex])
    }
}

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension String {
    mutating func addNewLine() {
        self.write("\r\n")
    }
}

extension CLLocationCoordinate2D {
    func coordinateToDMS() -> String {
        let latDms = toDms(dms: latitude)
        let lonDms = toDms(dms: longitude)

        let format = "%02d%02d%03d%@" + "%03d%02d%03d%@"
        return String(format: format, latDms.0, latDms.1, latDms.2, latitude >= 0 ? "N" : "S",
                      lonDms.0, lonDms.1, lonDms.2, longitude >= 0 ? "E" : "W")
    }
    
    private func toDms(dms: Double) -> (Int, Int, Int) {
        let degrees = abs(Int(dms))
        let minutes = Int((abs(dms) - abs(dms.rounded(.towardZero))) * 60)
        let seconds = Int(((abs(dms) - abs(dms.rounded(.towardZero)) - (Double(minutes)/60.0)) * 3600).rounded(.toNearestOrAwayFromZero))
        return (deg:degrees, min:minutes, sec:seconds)
    }
}
