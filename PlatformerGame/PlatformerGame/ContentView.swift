import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var gameScene: GameScene = {
        let scene = GameScene()
        scene.size = CGSize(width: 800, height: 500)
        scene.scaleMode = .aspectFill
        return scene
    }()

    var body: some View {
        ZStack {
            SpriteView(scene: gameScene)
                .ignoresSafeArea()

            #if os(iOS)
            touchControlsOverlay
            #endif
        }
    }

    #if os(iOS)
    var touchControlsOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                // Left side: D-Pad
                HStack(spacing: 12) {
                    // Left button
                    TouchButton(label: "<") {
                        gameScene.touchMoveDirection = -1
                    } onRelease: {
                        if gameScene.touchMoveDirection < 0 {
                            gameScene.touchMoveDirection = 0
                        }
                    }

                    // Right button
                    TouchButton(label: ">") {
                        gameScene.touchMoveDirection = 1
                    } onRelease: {
                        if gameScene.touchMoveDirection > 0 {
                            gameScene.touchMoveDirection = 0
                        }
                    }
                }
                .padding(.leading, 30)

                Spacer()

                // Right side: Action buttons
                HStack(spacing: 12) {
                    // Attack button
                    TouchButton(label: "ATK", color: .red) {
                        gameScene.touchAttack = true
                    } onRelease: {}

                    // Jump button
                    TouchButton(label: "JMP", color: .blue) {
                        gameScene.touchJump = true
                    } onRelease: {}
                }
                .padding(.trailing, 30)
            }
            .padding(.bottom, 30)
        }
    }
    #endif
}

#if os(iOS)
struct TouchButton: View {
    let label: String
    var color: Color = .white
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 64, height: 64)
            .background(
                Circle()
                    .fill(color.opacity(isPressed ? 0.6 : 0.3))
                    .overlay(Circle().stroke(color.opacity(0.7), lineWidth: 2))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
    }
}
#endif

#Preview {
    ContentView()
}
