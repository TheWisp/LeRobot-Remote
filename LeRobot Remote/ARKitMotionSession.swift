//
//  ARKitMotionSession.swift
//  LeRobot Remote
//
//  Created by Fei Teng on 05/07/2025.
//

import ARKit
import simd

/// Starts an ARKit world-tracking session and prints the phone’s pose.
final class ARKitMotionSession: NSObject, ARSessionDelegate {

    private let session = ARSession()
    private var origin = simd_float4x4(1)   // first-frame reference
    private var originEuler = SIMD3<Float>(repeating: 0)   // first-frame orientation
    
    private var latestPosition: SIMD3<Float> = .zero
    private var latestEulerAngles: SIMD3<Float> = .zero
    
    private func rad2deg(_ r: Float) -> Float { r * 180 / .pi }
    
    public var x: Float { latestPosition.x }
    public var y: Float { latestPosition.y }
    public var z: Float { latestPosition.z }
    public var pitch: Float { rad2deg(latestEulerAngles.x) }
    public var yaw: Float { rad2deg(latestEulerAngles.y) }
    public var roll: Float { rad2deg(latestEulerAngles.z) }

    override init() {
        super.init()

        // 1. Make sure the device can do 6-DoF AR.
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("ARKit world tracking isn’t supported on this device.")
        }

        // 2. Configure & run the session.
        let config = ARWorldTrackingConfiguration()
        session.delegate = self
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        // 1. Remember the first frame so we can express pose *relative* to it
        if frame.timestamp == 0 {
            origin       = frame.camera.transform
            originEuler  = frame.camera.eulerAngles        // (pitch, yaw, roll) in rad
        }

        // 2. ---------- POSITION ----------
        // camera pose relative to the origin
        let rel = origin.inverse * frame.camera.transform
        let p   = SIMD3<Float>(rel.columns.3.x,
                               rel.columns.3.y,
                               rel.columns.3.z)
        latestPosition = p

        // 3. ---------- ORIENTATION ----------
        // current Euler angles in world space
        let e      = frame.camera.eulerAngles              // rad
        // subtract the first-frame angles to get *relative* orientation
        let relE   = e - originEuler                       // rad
        latestEulerAngles = relE

        let pitch  = rad2deg(relE.x)                       // deg
        let yaw    = rad2deg(relE.y)
        let roll   = rad2deg(relE.z)

        // 4. Print it all
        print(String(format: "x: %.3f  y: %.3f  z: %.3f  |  pitch: %.1f°  yaw: %.1f°  roll: %.1f°",
                     p.x, p.y, p.z, pitch, yaw, roll))
    }
}
