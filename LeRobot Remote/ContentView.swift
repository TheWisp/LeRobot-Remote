import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CommandViewModel
    
    var body: some View {
        HStack {
            JoystickView(onMove: { x, y in
                viewModel.handleJoystickMove(x: x, y: y)
            }).offset(x:-225, y:87)
        }
        .padding()
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView(viewModel: CommandViewModel())
}
