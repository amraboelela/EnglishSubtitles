//
//  Logger.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela
//

import Foundation

/// Thread-safe logging function that ensures all logs are printed on the main thread
/// This fixes Xcode 26 logging issues where logs from background threads don't appear
func log(_ msg: String) {
    DispatchQueue.main.async {
        print(msg)
    }
}
