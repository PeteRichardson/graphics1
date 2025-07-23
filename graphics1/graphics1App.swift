//
//  graphics1App.swift
//  graphics1
//
//  Created by Peter Richardson on 7/23/25.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var debug: Bool = false
}

@main
struct graphics1App: App {
    @StateObject private var appState = AppState()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }.commands {
            CommandMenu("Debug") {
                Toggle("Show Debug Info", isOn: $appState.debug)
                    .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}
