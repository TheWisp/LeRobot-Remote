import Foundation
import CoreMotion

class CommandViewModel: ObservableObject {
    private var motionManager = CMMotionManager()
    private var arKitMotionSession = ARKitMotionSession()
    
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
    var gripper: Double = 0 {
        didSet { hasChanged = true }
    }

    var smoothedArKit: vector = .init(x: 0, y: 0, z: 0)
    var lastSmoothedArKit: vector?

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

    func handleGripperMove(value: Double) {
        self.gripper = value
    }
    
    func handleMotion() {
        guard let attitude = motionManager.deviceMotion?.attitude else { return }
        
        let yawRadian = attitude.yaw //TODO currently this gets incorrect value when the screen is facing down
        let yawDegree = yawRadian * 180.0 / .pi
        if abs(self.yaw - yawDegree) > LeKiwiConstants.motionAttitudeTolerance {
            self.yaw = yawDegree
        }
        
        let rollRadian = attitude.roll
        let rollDegree = rollRadian * 180.0 / .pi
        if abs(self.roll - rollDegree) > LeKiwiConstants.motionAttitudeTolerance {
            self.roll = rollDegree
        }
    }
    
    private func calculateWristState(yaw: Double, roll: Double) -> (roll: Double, flex: Double) {
        // The wristRoll calculation
        let wristRoll = max(
            min(-yaw * LeKiwiConstants.motionYawScale, LeKiwiConstants.wristRollMax),
            LeKiwiConstants.wristRollMin)
        // The wristFlex calculation
        let wristFlex = max(min(-roll + 90, LeKiwiConstants.wristFlexMax), LeKiwiConstants.wristFlexMin)
        return (wristRoll, wristFlex)
    }
    
    private func computeDeltaArKit() -> vector {
        var deltaArKit = vector(x: 0, y: 0, z: 0)
        
        if lastSmoothedArKit == nil {
            lastSmoothedArKit = smoothedArKit
            return deltaArKit
        }
        
        if let last = lastSmoothedArKit {
            let dist = smoothedArKit.distance(to: last)
            if dist > LeKiwiConstants.minimumChange {
                deltaArKit = smoothedArKit - last
            }
        }
        lastSmoothedArKit = smoothedArKit
        return deltaArKit
    }
    
    func update() {

        self.handleMotion()
        
        let arKitPosition: vector = .init(x: Double(arKitMotionSession.x), y: Double(arKitMotionSession.y), z: Double(arKitMotionSession.z))
        smoothedArKit = LeKiwiConstants.arKitSmoothingAlpha * arKitPosition + (1 - LeKiwiConstants.arKitSmoothingAlpha) * smoothedArKit
        
        if !hasChanged { return }
        hasChanged = false
        
        // Movement
        let forward = -self.joyY // Because Y is downwards in screen space
        let left = -self.joyX // Because X is towards right in screen space

        // End effector
        let (wristRoll, wristFlex) = calculateWristState(yaw: yaw, roll: roll)

        // Arm
        let deltaArKit = computeDeltaArKit()

        // ARKit to Robotics Axis Mapping:
        //   ARKit Y is up          -> Robotics Z is up
        //   ARKit X is right       -> Robotics Y is right
        //   ARKit Z (calculated)   -> Robotics X (Front)
        let robotDeltaUp = deltaArKit.y * LeKiwiConstants.robotDeltaScale
        let robotDeltaRight = -deltaArKit.x * LeKiwiConstants.robotDeltaScale
        let robotDeltaFront = -deltaArKit.z * LeKiwiConstants.robotDeltaScale

        let msg = """
        {
            "delta_x": \(robotDeltaFront),
            "delta_y": \(robotDeltaRight),
            "delta_z": \(robotDeltaUp),
            "arm_wrist_roll.pos": \(wristRoll),
            "arm_wrist_flex.pos": \(wristFlex),
            "arm_gripper": \(gripper),
            "x.vel": \(forward),
            "y.vel": \(left)
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

