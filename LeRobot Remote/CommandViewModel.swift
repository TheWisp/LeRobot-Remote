import Foundation

class CommandViewModel: ObservableObject {
    var hasChanged: Bool = false
    var joyX: Double = 0 {
        didSet { hasChanged = true }
    }
    var joyY: Double = 0 {
        didSet { hasChanged = true }
    }

    func handleJoystickMove(x: Double, y: Double) {
        self.joyX = x
        self.joyY = y
    }
    
    func update() {
        if !hasChanged { return }
        hasChanged = false
        
        // Movement
        let xy_speed = 0.4 // High speed
        let forward = -self.joyY // Because Y is downwards in screen space
        let left = -self.joyX // Because X is towards right in screen space
        
        let raw = bodyToWheelRaw(xCmd: left * xy_speed, yCmd: forward * xy_speed, thetaCmd: 0)
        DispatchQueue.main.async {
            let msg = """
            {
                "raw_velocity" : {
                    "left_wheel" : \(raw[0]),
                    "back_wheel" : \(raw[1]),
                    "right_wheel" : \(raw[2])
                },
                "arm_positions" : []
            }
            """
            send_packet(msg.cString(using: String.Encoding.ascii))
        }
        
        // Arm
        
    }
}
