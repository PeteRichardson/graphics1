//
//  ContentView.swift
//  graphics1
//
//  Created by Peter Richardson on 7/23/25.
//

import QuartzCore
import SwiftUI

/// Tuning constants and time-stepping maths for drag-release inertia.
enum Inertia {
    /// Nominal timer cadence. The step integrates against *measured* elapsed
    /// time, so a late tick is corrected for rather than assumed away.
    static let tickInterval: TimeInterval = 1.0 / 60.0

    /// Ticks per second that `friction` was tuned against.
    static let referenceRate: Double = 60

    /// Fraction of an item's velocity retained per reference tick.
    static let friction: CGFloat = 0.92

    /// Below this speed, in points per second, an item is considered at rest.
    static let restThreshold: CGFloat = 0.5

    /// Weight given to the newest sample when smoothing drag velocity.
    static let velocitySmoothing: CGFloat = 0.7

    /// Fraction of velocity retained after `dt` seconds.
    ///
    /// `friction` is a per-tick figure, so it is raised to the number of
    /// reference ticks `dt` actually covers. At exactly one tick this returns
    /// `friction` unchanged, which is what preserves the original feel.
    static func decay(dt: TimeInterval) -> CGFloat {
        CGFloat(pow(Double(friction), dt * referenceRate))
    }
}

extension Color {
    static func random() -> Color {
        let all: [Color] = [
            .blue, .brown, .cyan, .gray, .green, .indigo, .mint,
            .orange, .pink, .purple, .red, .teal, .yellow,
        ]
        return all.randomElement() ?? .black
    }
}

struct Item {
    var position: CGPoint = .init(x: 100, y: 100)
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

    var path: Path {
        Path(ellipseIn: boundingBox)
    }

    /// Hit test against the *rotated* ellipse, so grabbing matches what's drawn.
    func contains(_ point: CGPoint) -> Bool {
        path.applying(transform).contains(point)
    }

    /// A filled circle of `radius` centred on `point`.
    ///
    /// Internal rather than private so the geometry can be unit tested; it is
    /// only meaningfully called from `draw(in:debug:selected:)`.
    static func dot(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }

    func draw(in ctx: GraphicsContext, debug: Bool = false, selected: Bool = false) {
        let transform = self.transform
        let rotatedItemPath = path.applying(transform)
        ctx.fill(rotatedItemPath, with: .color(color))

        // The selection outline traces the shape itself rather than its
        // bounding box, so it reads as "this oval" and not "this rectangle".
        // Drawn after the fill so it is never painted over.
        if selected {
            ctx.stroke(
                rotatedItemPath,
                with: .color(Item.selectionColor),
                lineWidth: Item.selectionLineWidth
            )
        }

        // DRAW ONLY WHEN DEBUGGING
        if debug {
            let rotatedPath = Path(boundingBox).applying(transform)
            ctx.stroke(rotatedPath, with: .color(debugColor), lineWidth: 1)

            let dot = Item.dot(at: center, radius: 2) // no need to transform the dot...
            ctx.fill(dot, with: .color(debugColor))
        }
    }
}

extension Item {
    /// Colour of the selection outline. Uses the app accent so it follows the
    /// system tint rather than fighting an item's own colour.
    static let selectionColor: Color = .accentColor

    /// Wide enough to read against a filled shape at a glance.
    static let selectionLineWidth: CGFloat = 3
}

struct ContentView: View {
    @State private var items: [Item] = [Item(position: CGPoint(x: 200, y: 300)), Item(position: CGPoint(x: 300, y: 200), color: .green)]
    @State private var selectedItem: Int = 0
    @EnvironmentObject var appState: AppState
    @GestureState private var dragOffset: CGSize = .zero
    @State private var draggedItem: Int? = nil
    @State private var lastDragTime: Date? = nil
    @State private var lastTranslation: CGSize = .zero
    @State private var inertiaTimer: Timer? = nil
    @State var canvasCenter: CGPoint = .zero

    // A VStack rather than a ZStack overlay. Buttons are hit-testable views, so
    // while the bar sat in front of the canvas anything drawn underneath one was
    // unreachable: the click went to the button and `itemIndex(at:)` never ran.
    // Giving the bar its own row means the canvas simply stops where the bar
    // starts, and every point the canvas draws on is a point it can be grabbed at.
    var body: some View {
        VStack(spacing: 0) {
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
                        items[hit].velocity = .zero // grabbing it stops any coasting
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
                Canvas { ctx, _ in
                    for (i, item) in items.enumerated() {
                        var previewItem = item
                        if i == draggedItem {
                            // Live preview: only the dragged item follows the cursor.
                            previewItem.position.x += dragOffset.width
                            previewItem.position.y += dragOffset.height
                        }
                        previewItem.draw(
                            in: ctx,
                            debug: appState.debug,
                            selected: i == selectedItem
                        )
                    }
                }
                .gesture(dragGesture)
                // geo.size is now the canvas's own row rather than the whole
                // window, so this centres an item in the region it can be seen
                // and grabbed in — not behind the bar.
                .onChange(of: geo.size, initial: true) {
                    canvasCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }

            HStack {
                Button(action: {
                    items[selectedItem].color = Color.random()
                }) {
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
            }
            .padding()
        }
        .onDisappear(perform: stopInertia)
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

        let smoothing = Inertia.velocitySmoothing
        items[i].velocity.width = items[i].velocity.width * (1 - smoothing) + vx * smoothing
        items[i].velocity.height = items[i].velocity.height * (1 - smoothing) + vy * smoothing

        lastDragTime = value.time
        lastTranslation = value.translation
    }

    func startInertia() {
        guard inertiaTimer == nil else { return } // one timer coasts every moving item

        var lastTick = CACurrentMediaTime()

        let timer = Timer(timeInterval: Inertia.tickInterval, repeats: true) { timer in
            // Integrate against real elapsed time. Timer coalesces late fires
            // rather than catching up, so assuming a fixed step would make
            // motion slow down whenever the main thread is busy.
            let now = CACurrentMediaTime()
            let dt = now - lastTick
            lastTick = now
            guard dt > 0 else { return }

            let decay = Inertia.decay(dt: dt)
            var stillMoving = false

            for i in items.indices {
                guard i != draggedItem else { continue } // a held item doesn't coast

                // Velocity is points per second, so distance is velocity * dt
                items[i].position.x += items[i].velocity.width * CGFloat(dt)
                items[i].position.y += items[i].velocity.height * CGFloat(dt)

                // Apply simple friction, scaled to the time actually elapsed
                items[i].velocity.width *= decay
                items[i].velocity.height *= decay

                // Stop if velocity is small
                if abs(items[i].velocity.width) < Inertia.restThreshold,
                   abs(items[i].velocity.height) < Inertia.restThreshold
                {
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

        // .common rather than the default mode: a default-mode timer stops
        // firing while the run loop is tracking a live resize or an open menu,
        // which froze coasting items mid-flight.
        RunLoop.main.add(timer, forMode: .common)
        inertiaTimer = timer
    }

    /// Stop the simulation when the view goes away — the timer's closure
    /// otherwise outlives the view that owns it.
    func stopInertia() {
        inertiaTimer?.invalidate()
        inertiaTimer = nil
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
