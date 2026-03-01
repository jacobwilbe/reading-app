import Foundation

enum RecommendationSource: String, Codable, CaseIterable, Identifiable {
    case wikisource = "Wikisource"
    case wikipedia = "Wikipedia"
    case internetArchive = "Internet Archive"
    case chroniclingAmerica = "Chronicling America"

    var id: String { rawValue }
}

enum LicenseType: String, Codable, CaseIterable, Identifiable {
    case publicDomain = "Public Domain"
    case creativeCommons = "Creative Commons"
    case freeToRead = "Free-to-read"
    case varies = "Varies"
    case unknown = "Unknown"

    var id: String { rawValue }
}

struct ArticleCandidate: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let url: String
    let source: RecommendationSource
    let date: Date?
    let snippet: String
    let licenseType: LicenseType
    let language: String
    var wordCount: Int?
    var rawLengthFields: [String: String]
    var extractionFailed: Bool
}

enum LicenseFilter: String, CaseIterable, Identifiable, Codable {
    case any = "Any"
    case publicDomain = "Public Domain"
    case creativeCommons = "Creative Commons"
    case freeToRead = "Free-to-read"

    var id: String { rawValue }

    func allows(_ license: LicenseType) -> Bool {
        switch self {
        case .any:
            return true
        case .publicDomain:
            return license == .publicDomain
        case .creativeCommons:
            return license == .creativeCommons
        case .freeToRead:
            return license == .freeToRead
        }
    }
}

struct RecommendationRequest: Hashable {
    let topic: String
    let minutes: Int
    let licenseFilter: LicenseFilter
    let language: String
    let wpm: Int
    let allowSlightlyOver: Bool
    let preferRecent: Bool
    let mockMode: Bool
    let excludedURLs: [String]

    var cacheKey: String {
        let excludedKey = excludedURLs
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: ",")

        return [
            topic.lowercased(),
            String(minutes),
            licenseFilter.rawValue,
            language.lowercased(),
            String(wpm),
            String(allowSlightlyOver),
            String(preferRecent),
            String(mockMode),
            excludedKey
        ].joined(separator: "|")
    }
}

struct RecommendationResult {
    let topThree: [ArticleCandidate]
    let backups: [ArticleCandidate]
}
