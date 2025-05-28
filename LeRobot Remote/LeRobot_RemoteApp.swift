import SwiftUI

@main
struct LeRobot_RemoteApp: App {
    @StateObject private var viewModel = CommandViewModel()
    
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
    }
    
    func connectLeKiwi() throws {
        init_zmq()
    }
}
