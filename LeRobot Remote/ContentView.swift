import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CommandViewModel
    @State private var sliderValue: Double = 1.0
    
    var body: some View {
        HStack {
            JoystickView(onMove: { x, y in
                viewModel.handleJoystickMove(x: x, y: y)
            }).offset(x:-225, y:87)
            RoundVerticalSlider(value: $sliderValue, size: 150) { newValue in
                viewModel.handleGripperMove(value: newValue)
            }
            .offset(x: 225, y: 87)
        }
        .padding()
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView(viewModel: CommandViewModel())
}
