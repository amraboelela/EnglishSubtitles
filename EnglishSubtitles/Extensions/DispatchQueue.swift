//
//  DispatchQueue.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/3/25.
//

import Foundation

// Extension to safely bridge DispatchQueue with Swift Concurrency
extension DispatchQueue {
    func sync<T>(execute work: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            self.async {
                continuation.resume(returning: work())
            }
        }
    }
}
