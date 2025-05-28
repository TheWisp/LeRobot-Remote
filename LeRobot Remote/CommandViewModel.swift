import Foundation

class CommandViewModel: ObservableObject {
    @Published var joyX: CGFloat = 0
    @Published var joyY: CGFloat = 0
    
    func handleJoystickMove(x: CGFloat, y: CGFloat) {
        self.joyX = x
        self.joyY = y
        
        /**
         {"raw_velocity": wheel_commands, "arm_positions": arm_positions}
         
         wheel_commands is
         {"left_wheel": value, "back_wheel": value, "right_wheel": value}
         
         */
        DispatchQueue.main.async {
            let msg = """
            {
                "raw_velocity" : {
                    "left_wheel" : 0.2,
                    "back_wheel" : 0.2,
                    "right_wheel" : 0.2,
                },
                "arm_positions" : []
            }
            """
            send_packet(msg.cString(using: String.Encoding.ascii))
        }
        
    }
}
