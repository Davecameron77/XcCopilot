//
//  DmsQuadtree.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-30.
//

import Foundation
import MapKit

class DmsQuadtree {
    
    var myRegion: MyCoordinateRegion
    var capacity: Int
    var points: [MapMark]
    var divided: Bool
    var northeast: DmsQuadtree?
    var northwest: DmsQuadtree?
    var southeast: DmsQuadtree?
    var southwest: DmsQuadtree?
    
    init(region: MyCoordinateRegion, capacity: Int) {
        self.myRegion = region
        self.capacity = capacity
        self.points = []
        self.divided = false
    }
    
    func subdivide() {
        let newLatSpan = myRegion.region.span.latitudeDelta * 0.5
        let newLongSpan = myRegion.region.span.longitudeDelta * 0.5
        
        let topLat = myRegion.region.center.latitude + newLatSpan * 0.5
        let bottomLat = myRegion.region.center.latitude - newLatSpan * 0.5
        let leftLong = myRegion.region.center.longitude - newLongSpan * 0.5
        let rightLong = myRegion.region.center.longitude + newLongSpan * 0.5
        let span = MKCoordinateSpan(latitudeDelta: newLatSpan, longitudeDelta: newLongSpan)
        
        northeast = DmsQuadtree(
            region: MyCoordinateRegion(region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: topLat, longitude: leftLong), span: span)),
            capacity: capacity
        )
        northwest = DmsQuadtree(
            region: MyCoordinateRegion(region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: topLat, longitude: rightLong), span: span)),
            capacity: capacity
        )
        southeast = DmsQuadtree(
            region: MyCoordinateRegion(region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: bottomLat, longitude: rightLong), span: span)),
            capacity: capacity
        )
        southwest = DmsQuadtree(
            region: MyCoordinateRegion(region: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: bottomLat, longitude: leftLong), span: span)),
            capacity: capacity
        )
        
        divided = true
    }
    
    func insert(_ mark: MapMark) -> Bool {

        // Not within this tree
        if !myRegion.region.contains(coords: mark.coords) {
            return false
        }
        
        if !divided && myRegion.count < capacity {
            // This tree has room
            points.append(mark)
            myRegion.count += 1
            return true
        } else {
            if !divided {
                // Subdivision is necessary
                subdivide()
                
                // Distribute nodes
                for mark in points {
                    if northeast!.insert(mark) {
                        continue
                    } else if northwest!.insert(mark) {
                        continue
                    } else if southeast!.insert(mark) {
                        continue
                    } else if southwest!.insert(mark) {
                        continue
                    }
                }

                points.removeAll()
            }
            
            // Subdivided, insert in the appropriate child
            if northeast!.insert(mark) {
                return true
            } else if northwest!.insert(mark) {
                return true
            } else if southeast!.insert(mark) {
                return true
            } else if southwest!.insert(mark) {
                return true
            }
        }
        
        return false
    }
    
    func query(within region: MKCoordinateRegion, result: inout [MapMark]) {
        if !myRegion.region.intersects(searchRegion: region) {
            return
        } else {
            for point in points {
                if region.contains(coords: point.coords) {
                    result.append(point)
                }
                if divided {
                    northeast?.query(within: region, result: &result)
                    northwest?.query(within: region, result: &result)
                    southwest?.query(within: region, result: &result)
                    southeast?.query(within: region, result: &result)
                }
            }
        }
    }
    
    ///
    /// Returns the contents of the QuadTree for display in heatmap
    ///
    func returnResults() -> [MyCoordinateRegion] {
        var results = [MyCoordinateRegion]()
        
        if divided {
            results.append(contentsOf: northwest!.returnResults())
            results.append(contentsOf: northeast!.returnResults())
            results.append(contentsOf: southeast!.returnResults())
            results.append(contentsOf: southwest!.returnResults())
            
            return results
        } else {
            return [myRegion]
        }
    }
}

