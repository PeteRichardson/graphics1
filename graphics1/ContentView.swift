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
    
    var path : Path {
        Path(ellipseIn: CGRect(x: position.x, y: position.y, width: width, height: height))
     }
    
    func draw(in ctx: GraphicsContext, debug: Bool = false) {
        let boundingBox = CGRect(x: position.x, y: position.y, width: width, height: height)
        let centerPoint = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
        
        let transform = CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
            .rotated(by: CGFloat(rotation.radians))
            .translatedBy(x: -centerPoint.x, y: -centerPoint.y)
        let rotatedItemPath = path.applying(transform)
        ctx.fill(rotatedItemPath, with: .color(self.color))
        
        // DRAW ONLY WHEN DEBUGGING
        if debug {
            let rotatedPath = Path(boundingBox).applying(transform)
            ctx.stroke(rotatedPath, with: .color(.black), lineWidth: 1)
            
            let dot = dotAtPoint(centerPoint, radius: 2)   // no need to transform the dot...
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
    @State private var velocity: CGSize = .zero
    @State private var inertiaTimer: Timer? = nil
    @State var canvasCenter: CGPoint = .zero
    
    var body: some View {
        ZStack {
            VStack {
                let dragGesture = DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        // Step 1: update position
                        items[selectedItem].position.x += value.translation.width
                        items[selectedItem].position.y += value.translation.height

                        // Step 2: compute velocity (pts/sec)
                        let dragDuration = value.time.timeIntervalSince(value.time.advanced(by: -0.1))
                        let vx = value.translation.width / dragDuration
                        let vy = value.translation.height / dragDuration
                        self.velocity = CGSize(width: vx, height: vy)

                        // Step 3: start inertia animation
                        startInertia()
                    }
                
                GeometryReader { geo in
                    Canvas { ctx, size in
                        for item in items {
                            var previewItem = item
                            previewItem.position.x += dragOffset.width
                            previewItem.position.y += dragOffset.height
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
    
    func startInertia() {
        inertiaTimer?.invalidate()

        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            // Move item based on current velocity
            items[selectedItem].position.x += velocity.width / 60
            items[selectedItem].position.y += velocity.height / 60

            // Apply simple friction
            velocity.width *= 0.92
            velocity.height *= 0.92

            // Stop if velocity is small
            if abs(velocity.width) < 0.5 && abs(velocity.height) < 0.5 {
                timer.invalidate()
                inertiaTimer = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
