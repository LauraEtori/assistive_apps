//
//  PathFinder.swift
//  ARKitTest
//
//  Created by Chris Seonghwan Yoon & Jeremy Ryan on 7/11/17.
//
// Pathfinder class calculates turns or "keypoints" given a path array of LocationInfo
//

import Foundation

public struct CurrentCoordinateInfo {
    public var location: LocationInfo
    public var transformMatrix: Matrix3 = Matrix3.identity
    
    public init(_ location: LocationInfo, transMatrix: Matrix3) {
        self.location = location
        self.transformMatrix = transMatrix
    }
    
    public init(_ location: LocationInfo) {
        self.location = location
    }
}

public struct LocationInfo {
    public var x: Float
    public var y: Float
    public var z: Float
    public var yaw: Float
    
    public init(x: Float, y: Float, z: Float, yaw: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.yaw = yaw
    }
}

public struct KeypointInfo {
    public var location: LocationInfo
    public var orientation: Vector3
}

class PathFinder {
    
    private let pathWidth: Scalar = 0.7
    private var crumbs: [LocationInfo]
    
    init(crums: [LocationInfo]) {
        self.crumbs = crums
    }
    
    public var keypoints: [KeypointInfo] {
        get {
            return getKeypoints(edibleCrums: crumbs)
        }
    }
    
    private func getKeypoints(edibleCrums: [LocationInfo]) -> [KeypointInfo] {
        var res = [KeypointInfo]()
        let firstKeypointLocation = edibleCrums.first!
        let firstKeypointOrientation = Vector3.x
        res.append(KeypointInfo(location: firstKeypointLocation, orientation: firstKeypointOrientation))
        
        res += calculateKeypoints(edibleCrums: edibleCrums)
        
        let lastKeypointLocation = edibleCrums.last!
        let lastKeypointOrientation = Vector3(_: [(res.last?.location.x)! - edibleCrums.last!.x,
                                                  0,
                                                  (res.last?.location.z)! - edibleCrums.last!.z]).normalized()
        res.append(KeypointInfo(location: lastKeypointLocation, orientation: lastKeypointOrientation))
        return res
    }
    
    func calculateKeypoints(edibleCrums: [LocationInfo]) -> [KeypointInfo] {
        var keypoints = [KeypointInfo]()
        
        let first_crum = edibleCrums.first
        let last_crum = edibleCrums.last
        let pointVec = Vector3.init(_: [(last_crum?.x)! - (first_crum?.x)!,
                                        (last_crum?.y)! - (first_crum?.y)!,
                                        (last_crum?.z)! - (first_crum?.z)!])
        
        let normVec = Matrix3.init(_: [0, 0, 1,
                                       0, 0, 0,
                                       -1, 0, 0]) * pointVec
        
        let unitNormVec = normVec.normalized()
        let unitPointVec = pointVec.normalized()
        
        let unitNormVec2 = unitPointVec.cross(unitNormVec)
        
        var listOfDistances = [Scalar]()
        
        for crum in edibleCrums {
            let c = Vector3.init([crum.x - (first_crum?.x)!, crum.y - (first_crum?.y)!, crum.z - (first_crum?.z)!])
            let a = c.dot(unitNormVec2)
            let b = c.dot(unitNormVec)
            listOfDistances.append(sqrtf(powf(a, 2) + powf(b, 2)))
        }
        
        let maxDist = listOfDistances.max()
        let maxIdx = listOfDistances.index(of: maxDist!)
        
        if (maxDist! > pathWidth) {
            let prevKeypoints = calculateKeypoints(edibleCrums: Array(edibleCrums[0..<(maxIdx!+1)]))
            let postKeypoints = calculateKeypoints(edibleCrums: Array(edibleCrums[maxIdx!...]))
            
            var prevKeypointLocation = edibleCrums.first!
            var prevKeypointOrientation = Vector3.x
            if (!prevKeypoints.isEmpty) {
                keypoints += prevKeypoints
                
                prevKeypointLocation = prevKeypoints.last!.location
                prevKeypointOrientation = prevKeypoints.last!.orientation
            }
            
            let prevKeypoint = KeypointInfo(location: prevKeypointLocation, orientation: prevKeypointOrientation)
            
            //            var newKeypoint: KeypointInfo!
            let newKeypointLocation = edibleCrums[maxIdx!]
            let newKeypointOrientation = Vector3(_: [prevKeypoint.location.x - newKeypointLocation.x,
                                                     0,
                                                     prevKeypoint.location.z - newKeypointLocation.z]).normalized()
            
            
            keypoints.append(KeypointInfo(location: newKeypointLocation, orientation: newKeypointOrientation))
            
            if (!postKeypoints.isEmpty) {
                keypoints += postKeypoints
            }
        }
        
        return keypoints
    }
    
}

