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
    @StateObject private var viewModel = SubtitlesViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 300, idealWidth: 500, maxWidth: 700,
                       minHeight: 40, idealHeight: 60, maxHeight: 100)
                .environmentObject(viewModel)
        }
        .defaultSize(width: 500, height: 60)
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save Audio...") {
                    viewModel.saveAudio()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Slight delay to ensure window is fully created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.configureWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func configureWindow() {
        guard let window = NSApplication.shared.windows.first else { return }

        // Make window always on top
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Completely remove titlebar and traffic lights
        window.styleMask = [.borderless, .fullSizeContentView]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Make window movable by dragging background
        window.isMovableByWindowBackground = true

        // Make window semi-transparent
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.7)

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
