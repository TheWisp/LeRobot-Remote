import SwiftUI

struct RoundVerticalSlider: View {
    @Binding var value: Double // Range 0...1
    var size: CGFloat = 150
    var onChanged: ((Double) -> Void)? = nil
    
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.4), lineWidth: size * 0.05)
                    .frame(width: size, height: size)

                VStack {
                    Spacer(minLength: 0)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: size * 0.3, height: size * 0.3)
                        .offset(y: thumbOffsetY(in: geo.size))
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation
                                }
                                .onChanged { gesture in
                                    let percent = max(0, min(1, 1 - (gesture.location.y / geo.size.height)))
                                    self.value = percent
                                    self.onChanged?(percent)
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        self.value = 1.0
                                        self.onChanged?(1.0)
                                    }
                                }
                        )
                    Spacer(minLength: 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(width: size, height: size)
    }
    
    private func thumbOffsetY(in size: CGSize) -> CGFloat {
        let percent = 1 - value
        return (size.height * (percent - 0.5))
    }
}

#Preview {
    StatefulPreviewWrapper(1.0) { RoundVerticalSlider(value: $0) }
}

// Helper for previewing with @Binding
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }
    var body: some View {
        content($value)
    }
}
