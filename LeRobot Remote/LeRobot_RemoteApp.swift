import SwiftUI
import Foundation

@objcMembers
public class LeKiwiHostConfig: NSObject {
    public static let remoteIP = "192.168.1.137"
    public static let cmdPort = "5555"
    public static let videoPort = "5556"
}

@main
struct LeRobot_RemoteApp: App {
    private var viewModel = CommandViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
    
    init() {
        do {
            try connectLeKiwi()
        } catch {
            fatalError("Failed to connect to LeKiwi: \(error)")
        }
        
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            self.runLoop()
        }
    }
    
    func runLoop() {
        while true {
            viewModel.update()
            Thread.sleep(forTimeInterval: 0.001)
        }
    }
    
    
    func connectLeKiwi() throws {
        init_zmq(LeKiwiHostConfig.remoteIP, LeKiwiHostConfig.cmdPort, LeKiwiHostConfig.videoPort)
    }
}
