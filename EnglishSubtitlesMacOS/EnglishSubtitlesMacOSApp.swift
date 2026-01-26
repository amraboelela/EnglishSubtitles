//
//  EnglishSubtitlesMacOSApp.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/20/26.
//

import SwiftUI
import AppKit

@main
struct EnglishSubtitlesMacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, idealWidth: 800, maxWidth: 1200,
                       minHeight: 30, idealHeight: 45, maxHeight: 60)
        }
        .defaultSize(width: 800, height: 45)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Slight delay to ensure window is fully created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.configureWindow()
        }
    }

    private func configureWindow() {
        guard let window = NSApplication.shared.windows.first else { return }

        // Make window always on top
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at bottom center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth = window.frame.width
            let windowHeight = window.frame.height

            // Center horizontally, 100 pixels from bottom
            let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            let y = screenFrame.origin.y + 100

            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
