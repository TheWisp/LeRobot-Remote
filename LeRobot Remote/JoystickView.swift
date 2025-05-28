import SwiftUI

/// A virtual joystick that reports a normalized (−1…1) x/y value as you drag.
struct JoystickView: View {
    // MARK: Public API
    
    /// Called whenever the joystick’s position changes.
    var onMove: (_ x: CGFloat, _ y: CGFloat) -> Void
    
    /// Size of the joystick base
    var size: CGFloat = 150
    
    /// Size of the knob
    var knobSize: CGFloat = 60
    
    // MARK: Internal state
    
    @State private var dragOffset: CGSize = .zero
    
    private var radius: CGFloat { (size - knobSize) / 2 }
    
    var body: some View {
        // Base and knob stacked
        ZStack {
            // Base circle
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
            
            // Knob
            Circle()
                .fill(Color.blue)
                .frame(width: knobSize, height: knobSize)
                .offset(dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Compute vector from center
                            let translation = value.translation
                            let distance = sqrt(translation.width * translation.width
                                              + translation.height * translation.height)
                            
                            // Clamp to radius
                            if distance <= radius {
                                dragOffset = translation
                            } else {
                                // normalize and scale to radius
                                let clampedX = translation.width / distance * radius
                                let clampedY = translation.height / distance * radius
                                dragOffset = CGSize(width: clampedX, height: clampedY)
                            }
                            
                            // Normalize to [-1,1]
                            let normalizedX = dragOffset.width / radius
                            let normalizedY = dragOffset.height / radius
                            onMove(normalizedX, normalizedY)
                        }
                        .onEnded { _ in
                            // Return knob to center when released
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = .zero
                            }
                            onMove(0, 0)
                        }
                )
        }
    }
}
