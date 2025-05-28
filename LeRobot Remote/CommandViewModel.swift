import Foundation

class CommandViewModel: ObservableObject {
    @Published var joyX: CGFloat = 0
    @Published var joyY: CGFloat = 0

    /// Convert wheel angular speed (deg/s) into raw command ticks.
    static func degpsToRaw(_ degps: Double) -> Int {
        let stepsPerDeg = 4096.0 / 360.0
        let speedInSteps = abs(degps) * stepsPerDeg
        var speedInt = Int(speedInSteps.rounded())
        
        // Clamp to 15-bit max (0x7FFF)
        if speedInt > 0x7FFF {
            speedInt = 0x7FFF
        }
        
        // If negative, set the high bit; otherwise ensure it's cleared
        if degps < 0 {
            return speedInt | 0x8000
        } else {
            return speedInt & 0x7FFF
        }
    }

    /// Convert desired body-frame velocities into wheel raw commands.
    ///
    /// - Parameters:
    ///   - xCmd: Linear velocity in x (m/s).
    ///   - yCmd: Linear velocity in y (m/s).
    ///   - thetaCmd: Rotational velocity (deg/s).
    ///   - wheelRadius: Radius of each wheel (meters). Default 0.05.
    ///   - baseRadius: Distance from center to each wheel (meters). Default 0.125.
    ///   - maxRaw: Maximum allowed raw command (ticks) per wheel. Default 3000.
    /// - Returns: A list of Int raw commands.
    func bodyToWheelRaw(
        xCmd: Double,
        yCmd: Double,
        thetaCmd: Double,
        wheelRadius: Double = 0.05,
        baseRadius: Double = 0.125,
        maxRaw: Int = 3000
    ) -> [Int] {
        // Convert rotational velocity from deg/s to rad/s.
        let thetaRad = thetaCmd * (.pi / 180.0)

        // Body velocity vector [x, y, theta_rad].
        let v: [Double] = [xCmd, yCmd, thetaRad]

        // Wheel mounting angles (degrees → radians): [300°, 180°, 60°].
        let angles = [300.0, 180.0, 60.0].map { $0 * .pi / 180.0 }

        // Build kinematic matrix: each row [cos(a), sin(a), baseRadius].
        let m: [[Double]] = angles.map { angle in
            [cos(angle), sin(angle), baseRadius]
        }

        // Compute each wheel’s linear speed (m/s): m · v
        let wheelLinearSpeeds = m.map { row in
            zip(row, v).map(*).reduce(0, +)
        }

        // Convert linear → angular speed (rad/s).
        let wheelAngularSpeeds = wheelLinearSpeeds.map { $0 / wheelRadius }

        // Convert rad/s → deg/s.
        var wheelDegps = wheelAngularSpeeds.map { $0 * (180.0 / .pi) }

        // Compute raw floats to check for scaling.
        let stepsPerDeg = 4096.0 / 360.0
        let rawFloats = wheelDegps.map { abs($0) * stepsPerDeg }
        if let maxRawComputed = rawFloats.max(), maxRawComputed > Double(maxRaw) {
            let scale = Double(maxRaw) / maxRawComputed
            wheelDegps = wheelDegps.map { $0 * scale }
        }

        // Convert deg/s → raw Int commands.
        let wheelRaw = wheelDegps.map { CommandViewModel.degpsToRaw($0) }

        return wheelRaw
    }
    
    func handleJoystickMove(x: Double, y: Double) {
        self.joyX = x
        self.joyY = y
        //print("x: \(x), y: \(y)")
        
        let xy_speed = 0.4 // High speed
        let forward = -y
        let left = -x
        
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
        
    }
}
