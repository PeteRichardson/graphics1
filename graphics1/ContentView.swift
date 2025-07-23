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
    var rotation: Angle = .zero
    var color: Color = .blue
    
    var path : Path {
        Path(ellipseIn: CGRect(x: position.x, y: position.y, width: width, height: height))
     }
    
    func draw(in ctx: GraphicsContext, debug: Bool = false) {
        ctx.fill(path, with: .color(self.color))
        
        // DRAW ONLY WHEN DEBUGGING
        if debug {
            ctx.stroke(Path(boundingBox), with: .color(.black), lineWidth: 1)
            
            let dot = dotAtPoint(centerPoint, radius: 2)
            ctx.fill(dot, with: .color(.black))        }
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
    @State var item = Item()
    @State var debug = true
    
    var body: some View {
        ZStack {
            VStack {
                Canvas { ctx, size in
                    item.draw(in: ctx, debug: debug)
                }
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
                }
                .background(Color.secondary.opacity(0.1))
                .frame(maxWidth: 1000, maxHeight: 50)
            }
        }
    }
}

#Preview {
    ContentView()
}
