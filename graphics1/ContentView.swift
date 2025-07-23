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
    @State private var item = Item()
    @State private var debug = true
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            VStack {
                let dragGesture = DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        item.position.x += value.translation.width
                        item.position.y += value.translation.height
                    }
                
                Canvas { ctx, size in
                    var previewItem = item
                    previewItem.position.x += dragOffset.width
                    previewItem.position.y += dragOffset.height
                    previewItem.draw(in: ctx, debug: debug)
                }.gesture (dragGesture)
                
 
            }
            VStack {
                HStack {
                    Button(action: {
                        item.color = Color.random
                    }){
                        Label("Random Color", systemImage: "paintbrush")
                    }
                    Button(action: {
                        item.rotation -= .degrees(15)
                    }) {
                        Label("Rotate Left", systemImage: "rotate.left")
                    }
                    Button(action: {
                        item.rotation += .degrees(15)
                    }) {
                        Label("Rotate Right", systemImage: "rotate.right")
                    }
                    Button(action: {
                        debug.toggle()
                    }) {
                        Label("Debug", systemImage: "ant")
                    }
                }.padding()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

#Preview {
    ContentView()
}
