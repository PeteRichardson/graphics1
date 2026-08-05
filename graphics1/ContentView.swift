//
//  ContentView.swift
//  graphics1
//
//  Created by Peter Richardson on 7/23/25.
//

import SwiftUI

extension Color {
    static var random: Color {
        let all: [Color] = [
            .blue, .brown, .cyan, .gray, .green, .indigo, .mint,
            .orange, .pink, .purple, .red, .teal, .yellow
        ]
        return all.randomElement() ?? .black
    }
}

struct Item {
    var position: CGPoint = CGPoint(x:100, y:100)
    var height: CGFloat = 100
    var width: CGFloat = 200
    var rotation: Angle = .degrees(15)
    var color: Color = .blue
    var debugColor: Color = .black
    var velocity: CGSize = .zero

    var boundingBox: CGRect {
        CGRect(x: position.x, y: position.y, width: width, height: height)
    }

    var center: CGPoint {
        CGPoint(x: boundingBox.midX, y: boundingBox.midY)
    }

    /// Rotation about the item's center, built fresh from `position`/`rotation`.
    var transform: CGAffineTransform {
        let centerPoint = center
        return CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
            .rotated(by: CGFloat(rotation.radians))
            .translatedBy(x: -centerPoint.x, y: -centerPoint.y)
    }

    var path : Path {
        Path(ellipseIn: boundingBox)
     }

    /// Hit test against the *rotated* ellipse, so grabbing matches what's drawn.
    func contains(_ point: CGPoint) -> Bool {
        path.applying(transform).contains(point)
    }

    func draw(in ctx: GraphicsContext, debug: Bool = false) {
        let transform = self.transform
        let rotatedItemPath = path.applying(transform)
        ctx.fill(rotatedItemPath, with: .color(self.color))

        // DRAW ONLY WHEN DEBUGGING
        if debug {
            let rotatedPath = Path(boundingBox).applying(transform)
            ctx.stroke(rotatedPath, with: .color(.black), lineWidth: 1)

            let dot = dotAtPoint(center, radius: 2)   // no need to transform the dot...
            ctx.fill(dot, with: .color(self.debugColor))
        }
    }
}

func dotAtPoint(_ center: CGPoint, radius: CGFloat) -> Path {
    let circleRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    return Path(ellipseIn: circleRect)
}



struct ContentView: View {
    @State private var items : [Item] = [Item(position: CGPoint(x:200, y:300)), Item(position: CGPoint(x:300, y:200), color: .green)]
    @State private var selectedItem : Int = 0
    @EnvironmentObject var appState: AppState
    @GestureState private var dragOffset: CGSize = .zero
    @State private var draggedItem: Int? = nil
    @State private var lastDragTime: Date? = nil
    @State private var lastTranslation: CGSize = .zero
    @State private var inertiaTimer: Timer? = nil
    @State var canvasCenter: CGPoint = .zero

    var body: some View {
        ZStack {
            VStack {
                let dragGesture = DragGesture(minimumDistance: 1)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onChanged { value in
                        if draggedItem == nil {
                            // First change of this gesture: figure out what was grabbed.
                            guard let hit = itemIndex(at: value.startLocation) else { return }
                            draggedItem = hit
                            selectedItem = hit
                            items[hit].velocity = .zero   // grabbing it stops any coasting
                            lastDragTime = value.time
                            lastTranslation = value.translation
                            return
                        }
                        trackVelocity(value)
                    }
                    .onEnded { value in
                        defer {
                            draggedItem = nil
                            lastDragTime = nil
                            lastTranslation = .zero
                        }
                        guard let i = draggedItem else { return }

                        trackVelocity(value)

                        // Commit the live-preview offset into the real position.
                        items[i].position.x += value.translation.width
                        items[i].position.y += value.translation.height

                        startInertia()
                    }

                GeometryReader { geo in
                    Canvas { ctx, size in
                        for (i, item) in items.enumerated() {
                            var previewItem = item
                            if i == draggedItem {
                                // Live preview: only the dragged item follows the cursor.
                                previewItem.position.x += dragOffset.width
                                previewItem.position.y += dragOffset.height
                            }
                            previewItem.draw(in: ctx, debug: appState.debug)
                        }
                    }
                    .gesture(dragGesture)
                    .onChange(of: geo.size, initial: true) {
                        canvasCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
            }
            VStack {
                HStack {
                    Button(action: {
                        items[selectedItem].color = Color.random
                    }){
                        Label("Random Color", systemImage: "paintbrush")
                    }
                    Button(action: {
                        items[selectedItem].rotation -= .degrees(15)
                    }) {
                        Label("Rotate Left", systemImage: "rotate.left")
                    }
                    Button(action: {
                        items[selectedItem].rotation += .degrees(15)
                    }) {
                        Label("Rotate Right", systemImage: "rotate.right")
                    }
                    Button(action: {
                        items[selectedItem].position = CGPoint(
                            x: canvasCenter.x - items[selectedItem].width / 2,
                            y: canvasCenter.y - items[selectedItem].height / 2
                        )
                    }) {
                        Label("Center", systemImage: "dot.viewfinder")
                    }
                }.padding()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    /// Topmost item under `point`, or nil for empty canvas.
    /// Iterates in reverse because later items are drawn on top.
    func itemIndex(at point: CGPoint) -> Int? {
        items.indices.reversed().first { items[$0].contains(point) }
    }

    /// Velocity in pts/sec from the most recent slice of the drag, lightly
    /// smoothed so a jittery last event doesn't dominate the fling.
    func trackVelocity(_ value: DragGesture.Value) {
        guard let i = draggedItem, let previousTime = lastDragTime else { return }
        let dt = value.time.timeIntervalSince(previousTime)
        guard dt > 0 else { return }

        let vx = (value.translation.width - lastTranslation.width) / dt
        let vy = (value.translation.height - lastTranslation.height) / dt

        let smoothing = 0.7
        items[i].velocity.width = items[i].velocity.width * (1 - smoothing) + vx * smoothing
        items[i].velocity.height = items[i].velocity.height * (1 - smoothing) + vy * smoothing

        lastDragTime = value.time
        lastTranslation = value.translation
    }

    func startInertia() {
        guard inertiaTimer == nil else { return }   // one timer coasts every moving item

        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            var stillMoving = false

            for i in items.indices {
                guard i != draggedItem else { continue }   // a held item doesn't coast

                // Move item based on its own velocity
                items[i].position.x += items[i].velocity.width / 60
                items[i].position.y += items[i].velocity.height / 60

                // Apply simple friction
                items[i].velocity.width *= 0.92
                items[i].velocity.height *= 0.92

                // Stop if velocity is small
                if abs(items[i].velocity.width) < 0.5 && abs(items[i].velocity.height) < 0.5 {
                    items[i].velocity = .zero
                } else {
                    stillMoving = true
                }
            }

            if !stillMoving {
                timer.invalidate()
                inertiaTimer = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
