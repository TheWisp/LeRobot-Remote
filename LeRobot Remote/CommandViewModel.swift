import Foundation
import CoreMotion

class CommandViewModel: ObservableObject {
    private var motionManager = CMMotionManager()
    
    var hasChanged: Bool = false
    var joyX: Double = 0 {
        didSet { hasChanged = true }
    }
    var joyY: Double = 0 {
        didSet { hasChanged = true }
    }
    var yaw: Double = 0 {
        didSet { hasChanged = true }
    }
    
    init() {
        //motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates() //TODO hook up to a locking mechanism
    }

    func handleJoystickMove(x: Double, y: Double) {
        self.joyX = x
        self.joyY = y
    }
    
    func handleMotion() {
        guard let attitude = motionManager.deviceMotion?.attitude else { return }
        let yawRadian = attitude.yaw
        let yawDegree = yawRadian * 180.0 / .pi
        //print("yawDegree: \(String(describing: yawDegree))")
        
        if abs(self.yaw - yawDegree) > 0.2 {
            self.yaw = yawDegree
        }
    }
    
    func update() {
        self.handleMotion()
        
        if !hasChanged { return }
        hasChanged = false
        
        // Movement
        let xy_speed = 0.4 // High speed
        let forward = -self.joyY // Because Y is downwards in screen space
        let left = -self.joyX // Because X is towards right in screen space
        
        let rawVelocity = bodyToWheelRaw(xCmd: left * xy_speed, yCmd: forward * xy_speed, thetaCmd: 0)
        
        // Arm
        // The motor states are in [-90, 90] after calibration, whereas the yaw is 90 when rotated to the left, -90 to the right
        let wristRollMin = -90.0
        let wristRollMax = 90.0
        let yawScale = 2.5
        let wristRoll = max(min(-yaw * yawScale, wristRollMax), wristRollMin)
        
        
        let msg = """
        {
            "raw_velocity" : {
                "left_wheel" : \(rawVelocity[0]),
                "back_wheel" : \(rawVelocity[1]),
                "right_wheel" : \(rawVelocity[2])
            },
            "arm_partial_positions" : {
                "wrist_roll": \(wristRoll)
            }
        }
        """
        DispatchQueue.main.async {
            send_packet(msg.cString(using: String.Encoding.ascii))
        }
    }
}
