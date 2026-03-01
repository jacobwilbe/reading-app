import Foundation

enum ReadingSpeedSettings {
    static let defaultWPM: Int = 220

    static func maxWords(minutes: Int, wpm: Int) -> Int {
        max(0, minutes) * max(1, wpm)
    }

    static func estimatedMinutes(wordCount: Int, wpm: Int) -> Int {
        guard wordCount > 0 else { return 0 }
        return Int(ceil(Double(wordCount) / Double(max(1, wpm))))
    }
}
