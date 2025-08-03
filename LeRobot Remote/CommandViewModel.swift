import Foundation
import CoreMotion

struct vector {
    var x: Double
    var y: Double
    var z: Double
    
    // Implement common operators
    static func * (lhs: vector, rhs: Double) -> vector {
        return .init(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
    static func += (lhs: inout vector, rhs: vector) {
        lhs.x += rhs.x
        lhs.y += rhs.y
        lhs.z += rhs.z
    }
    static func -= (lhs: inout vector, rhs: vector) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        lhs.z -= rhs.z
    }
    
    //impl lengthSquared
    func lengthSquared() -> Double {
        return x * x + y * y + z * z
    }
}

class CommandViewModel: ObservableObject {
    private var motionManager = CMMotionManager()
    private var arKitMotionSession = ARKitMotionSession()
    
    // Constants
    static let motionAttitudeTolerance: Double = 0.05
    static let motionYawScale: Double = 3.2
    static let wristRollMin: Double = -55.0 //-90.0
    static let wristRollMax: Double = 75.0 //90.0
    static let wristFlexMin: Double = -90.0
    static let wristFlexMax: Double = 60.0
    static let moveXYSpeedHigh = 0.4
    static let arKitSmoothingAlpha: Double = 0.15
    
    var hasChanged: Bool = false
    var lastTimestamp: TimeInterval?
    
    var joyX: Double = 0 {
        didSet { hasChanged = true }
    }
    var joyY: Double = 0 {
        didSet { hasChanged = true }
    }
    var yaw: Double = 0 {
        didSet { hasChanged = true }
    }
    var roll: Double = 0 {
        didSet { hasChanged = true }
    }

    var velocity: vector = .init(x: 0, y: 0, z: 0)
    var displacement: vector = .init(x: 0, y: 0, z: 0) {
        didSet { hasChanged = true }
    }
    
    var smoothedArKit: vector = .init(x: 0, y: 0, z: 0)
    
    var lastSentVector: vector?

    init() {

        // Set your desired update rate
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0  // 60 Hz
        
        // Pick and validate a reference frame
        let frame: CMAttitudeReferenceFrame = .xArbitraryCorrectedZVertical
        let available = CMMotionManager.availableAttitudeReferenceFrames()
        guard CMMotionManager.availableAttitudeReferenceFrames().contains(frame) else {
            print("Reference frame \(frame) not supported — available: \(available)")
            return
        }
        
        motionManager.startDeviceMotionUpdates(using: frame)
    }
    
    func handleJoystickMove(x: Double, y: Double) {
        self.joyX = x
        self.joyY = y
    }
    
    func handleMotion() {
        guard let attitude = motionManager.deviceMotion?.attitude else { return }
        
        let yawRadian = attitude.yaw //TODO currently this gets incorrect value when the screen is facing down
        let yawDegree = yawRadian * 180.0 / .pi
        if abs(self.yaw - yawDegree) > CommandViewModel.motionAttitudeTolerance {
            self.yaw = yawDegree
        }
        
        let rollRadian = attitude.roll
        let rollDegree = rollRadian * 180.0 / .pi
        if abs(self.roll - rollDegree) > CommandViewModel.motionAttitudeTolerance {
            self.roll = rollDegree
        }
    }
    
    func update() {

        self.handleMotion()
        
        smoothedArKit.x = CommandViewModel.arKitSmoothingAlpha * Double(arKitMotionSession.x) + (1 - CommandViewModel.arKitSmoothingAlpha) * smoothedArKit.x
        smoothedArKit.y = CommandViewModel.arKitSmoothingAlpha * Double(arKitMotionSession.y) + (1 - CommandViewModel.arKitSmoothingAlpha) * smoothedArKit.y
        smoothedArKit.z = CommandViewModel.arKitSmoothingAlpha * Double(arKitMotionSession.z) + (1 - CommandViewModel.arKitSmoothingAlpha) * smoothedArKit.z
        
        if !hasChanged { return }
        hasChanged = false
        
        // Movement
        let forward = -self.joyY // Because Y is downwards in screen space
        let left = -self.joyX // Because X is towards right in screen space
        
        let rawVelocity = bodyToWheelRaw(
            xCmd: left * CommandViewModel.moveXYSpeedHigh,
            yCmd: forward * CommandViewModel.moveXYSpeedHigh,
            thetaCmd: 0)

        // Arm
        // The motor states are in [-90, 90] after calibration,
        // whereas the yaw is 90 when rotated to the left, -90 to the right
        let wristRoll = max(
            min(-yaw * CommandViewModel.motionYawScale, CommandViewModel.wristRollMax),
            CommandViewModel.wristRollMin)
        
        // The phone's roll is 0 when laying flat. This should map to gripper looking down.
        let wristFlex = max(min(-roll + 90, CommandViewModel.wristFlexMax), CommandViewModel.wristFlexMin)

        // Experimental EE movement
        let minimumChange: Double = 0.001
        
        var deltaArKitX: Double = 0
        var deltaArKitY: Double = 0
        var deltaArKitZ: Double = 0
        
        if lastSentVector == nil {
            lastSentVector = smoothedArKit
        }
        
        if let last = lastSentVector {
            if abs(smoothedArKit.x - last.x) > minimumChange {
                deltaArKitX = smoothedArKit.x - last.x
            }
            if abs(smoothedArKit.y - last.y) > minimumChange {
                deltaArKitY = smoothedArKit.y - last.y
            }
            if abs(smoothedArKit.z - last.z) > minimumChange {
                deltaArKitZ = smoothedArKit.z - last.z
            }
            
            lastSentVector = smoothedArKit
        }
        //if (deltaArKitX == 0 && deltaArKitY == 0 && deltaArKitZ == 0) {
        //    return
        //}
        
        // Debug delta
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"
        let shortTime = timeFormatter.string(from: Date())
        print("deltaX: \(String(format: "%.4f", deltaArKitX)), deltaY: \(String(format: "%.4f", deltaArKitY)), deltaZ: \(String(format: "%.4f", deltaArKitZ)), wristRoll: \(String(format: "%.2f", wristRoll)), wristFlex: \(String(format: "%.2f", wristFlex)), time: \(shortTime)")
        
        // ARKit to Robotics Axis Mapping:
        //   ARKit Y is up          -> Robotics Z is up
        //   ARKit X is right       -> Robotics Y is right
        //   ARKit Z (calculated)   -> Robotics X (Front)
        let robotDeltaScale = 7.5
        let robotDeltaUp = deltaArKitY * robotDeltaScale
        let robotDeltaRight = -deltaArKitX * robotDeltaScale
        let robotDeltaFront = -deltaArKitZ * robotDeltaScale

        let msg = """
        {
            "delta_x": \(robotDeltaFront),
            "delta_y": \(robotDeltaRight),
            "delta_z": \(robotDeltaUp),
            "arm_wrist_roll.pos": \(wristRoll),
            "arm_wrist_flex.pos": \(wristFlex)
        }
        """
 
        DispatchQueue.main.async {
            guard let cStr = msg.cString(using: String.Encoding.ascii) else {
                print("Failed to encode message to ASCII: \(msg)")
                return
            }
            send_packet(cStr)
        }
    }
}

