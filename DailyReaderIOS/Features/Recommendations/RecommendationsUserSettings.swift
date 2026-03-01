import Foundation

enum RecommendationsUserSettings {
    static let wpmKey = "recommendations.wpm"

    static func currentWPM(defaultValue: Int = ReadingSpeedSettings.defaultWPM) -> Int {
        let stored = UserDefaults.standard.integer(forKey: wpmKey)
        return stored > 0 ? stored : defaultValue
    }
}
