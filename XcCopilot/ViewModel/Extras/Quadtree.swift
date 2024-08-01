//
//  Quadtree.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-07-24.
//

import Foundation
import CoreGraphics

struct Rect: Hashable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var count = 0
    
    func contains(_ mark: MapMark) -> Bool {
        return mark.coords.latitude >= x &&
               mark.coords.longitude <= x + width &&
               mark.coords.latitude >= y &&
               mark.coords.longitude <= y + height
    }
    
    func intersects(_ range: Rect) -> Bool {
        return !(range.x > x + width ||
                 range.x + range.width < x ||
                 range.y > y + height ||
                 range.y + range.height < y)
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(x + y + width + height)
    }
}

class Quadtree {
    var boundary: Rect
    var capacity: Int
    var points: [MapMark]
    var divided: Bool
    var northeast: Quadtree?
    var northwest: Quadtree?
    var southeast: Quadtree?
    var southwest: Quadtree?
    
    init(boundary: Rect, capacity: Int) {
        self.boundary = boundary
        self.capacity = capacity
        self.points = []
        self.divided = false
    }
    
    func subdivide() {
        let x = boundary.x
        let y = boundary.y
        let w = boundary.width / 2
        let h = boundary.height / 2
        
        let ne = Rect(x: x + w, y: y, width: w, height: h)
        let nw = Rect(x: x, y: y, width: w, height: h)
        let se = Rect(x: x + w, y: y + h, width: w, height: h)
        let sw = Rect(x: x, y: y + h, width: w, height: h)
        
        northeast = Quadtree(boundary: ne, capacity: capacity)
        northwest = Quadtree(boundary: nw, capacity: capacity)
        southeast = Quadtree(boundary: se, capacity: capacity)
        southwest = Quadtree(boundary: sw, capacity: capacity)
        
        divided = true
    }
    
    ///
    /// Inserts the provided mark into the QuadTree
    ///
    func insert(_ mark: MapMark) -> Bool {
        // Make sure this node contains the DMS
        if !boundary.contains(mark) {
            return false
        }
        
        if !divided && points.count < capacity {
            // Append in this tree
            print("Insert")
            points.append(mark)
            return true
        } else {
            
            if !divided {
                // Subdivide if necessary
                print("Subdividing")
                subdivide()

                // Distribute nodes to children
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

                // Insert this point into the appropriate child
                if northeast!.insert(mark) {
                    return true
                } else if northwest!.insert(mark) {
                    return true
                } else if southeast!.insert(mark) {
                    return true
                } else if southwest!.insert(mark) {
                    return true
                }
            } else {
                // Insert this point into the appropriate child
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
        }
        
        return false
    }
    
    ///
    /// Searches the tree to see if a point is already stored
    ///
    /// - Parameter range: The rect to search
    /// - Parameter found: The search results
    func query(range: Rect, found: inout [MapMark]) {
        if !boundary.intersects(range) {
            return
        } else {
            for point in points {
                if range.contains(point) {
                    found.append(point)
                }
            }
            if divided {
                northeast?.query(range: range, found: &found)
                northwest?.query(range: range, found: &found)
                southeast?.query(range: range, found: &found)
                southwest?.query(range: range, found: &found)
            }
        }
    }
    
    ///
    /// Returns the contents of the QuadTree for display in heatmap
    ///
    func returnResults() -> [Rect] {
        var results = [Rect]()
        
        if divided {
            results.append(contentsOf: northwest!.returnResults())
            results.append(contentsOf: northeast!.returnResults())
            results.append(contentsOf: southeast!.returnResults())
            results.append(contentsOf: southwest!.returnResults())
            
            return results
        } else {
            boundary.count = points.count
            
            return [boundary]
        }
    }
}
