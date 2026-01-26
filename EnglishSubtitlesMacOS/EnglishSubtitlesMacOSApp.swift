//
//  EnglishSubtitlesMacOSApp.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/20/26.
//

import SwiftUI

@main
struct EnglishSubtitlesMacOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, idealWidth: 800, maxWidth: 1000,
                       minHeight: 200, idealHeight: 300, maxHeight: 400)
        }
        .defaultSize(width: 800, height: 300)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
