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
    static let arKitZSmoothingAlpha: Double = 0.15
    
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
    
    var smoothedArKitZ: Double = 0.0
    
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
        
        smoothedArKitZ = CommandViewModel.arKitZSmoothingAlpha * Double(arKitMotionSession.z) + (1 - CommandViewModel.arKitZSmoothingAlpha) * smoothedArKitZ
        
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

        //experimental, when lifted 0.01m = changing from 180 to 135 degrees
        let shoulderLiftStart = 191.0
        let shoulderLiftEnd = 135.0
        let shoulderLiftMappedDistance = 0.1
        var shoulderLiftGoalDegree = shoulderLiftStart + (shoulderLiftEnd - shoulderLiftStart)
            * min(max(smoothedArKitZ / shoulderLiftMappedDistance, 0.0), 1.0)
        
        // elbow_flex after calibration: -110 (open) to 8 (closed)
        let elbowFlexStart = 8.0
        let elbowFlexEnd = -110.0
        let elbowFlexMappedDistance = 0.1
        
        let elbowFlexGoalDegree = elbowFlexStart + (elbowFlexEnd - elbowFlexStart)
        * min(max(smoothedArKitZ / elbowFlexMappedDistance, 0.0), 1.0)
        
        var msg = """
        {
            "raw_velocity" : {
                "left_wheel" : \(rawVelocity[0]),
                "back_wheel" : \(rawVelocity[1]),
                "right_wheel" : \(rawVelocity[2])
            },
            "arm_partial_positions" : {
                "wrist_roll": \(wristRoll),
                "wrist_flex": \(wristFlex),
                "shoulder_lift": \(shoulderLiftGoalDegree),
                "elbow_flex": \(elbowFlexGoalDegree)
            }
        }
        """
        
        let dbgMsg = """
        {
            "raw_velocity" : {
                "left_wheel" : \(rawVelocity[0]),
                "back_wheel" : \(rawVelocity[1]),
                "right_wheel" : \(rawVelocity[2])
            },
            "arm_partial_positions" : {
                "shoulder_lift": \(shoulderLiftGoalDegree),
                "elbow_flex": \(elbowFlexGoalDegree)
            }
        }
        """
        
        // Debug
        //msg = dbgMsg

        DispatchQueue.main.async {
            send_packet(msg.cString(using: String.Encoding.ascii))
        }
    }
}

