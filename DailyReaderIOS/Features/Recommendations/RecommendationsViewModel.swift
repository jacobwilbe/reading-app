import Foundation
import SwiftUI

@MainActor
final class RecommendationsViewModel: ObservableObject {
    @Published var topic: String = ""
    @Published var minutes: Int = 10
    @Published var licenseFilter: LicenseFilter = .any
    @Published var language: String = "en"
    @Published var allowSlightlyOver: Bool = true
    @Published var preferRecent: Bool = false
    @Published var useMockMode: Bool = false

    @Published private(set) var isLoading = false
    @Published private(set) var result = RecommendationResult(topThree: [], backups: [])
    @Published var errorMessage: String?

    @Published var presentedURLItem: PresentedURL?
    @Published var linkNotice: String?

    private let service: RecommendationsService
    private let session = URLSession.shared
    private var excludedURLs: Set<String> = []
    private var lastSearchSignature: String?

    init(service: RecommendationsService = RecommendationsService()) {
        self.service = service
    }

    var hasSearched: Bool {
        !result.topThree.isEmpty || !result.backups.isEmpty || errorMessage != nil
    }

    var hasNoResults: Bool {
        hasSearched && result.topThree.isEmpty && !isLoading
    }

    var suggestedMinutes: [Int] {
        [minutes + 2, minutes + 5]
    }

    var effectiveWPM: Int {
        RecommendationsUserSettings.currentWPM()
    }

    var maxWordsForSelectedTime: Int {
        ReadingSpeedSettings.maxWords(minutes: minutes, wpm: effectiveWPM)
    }

    func search() async {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else {
            errorMessage = "Enter a subject to search."
            result = RecommendationResult(topThree: [], backups: [])
            return
        }

        let signature = [
            trimmedTopic.lowercased(),
            String(minutes),
            licenseFilter.rawValue,
            language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            String(allowSlightlyOver),
            String(preferRecent),
            String(useMockMode)
        ].joined(separator: "|")

        if lastSearchSignature != signature {
            excludedURLs.removeAll()
            lastSearchSignature = signature
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let request = RecommendationRequest(
            topic: trimmedTopic,
            minutes: minutes,
            licenseFilter: licenseFilter,
            language: language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "en" : language,
            wpm: effectiveWPM,
            allowSlightlyOver: allowSlightlyOver,
            preferRecent: preferRecent,
            mockMode: useMockMode,
            excludedURLs: Array(excludedURLs)
        )

        let output = await service.search(request: request)
        result = output

        if output.topThree.isEmpty {
            errorMessage = nil
        }
    }

    func tryAgain() async {
        for candidate in result.topThree {
            excludedURLs.insert(candidate.url.lowercased())
        }
        await search()
    }

    func estimatedMinutes(for candidate: ArticleCandidate) -> Int? {
        guard let words = candidate.wordCount, words > 0 else { return nil }
        return ReadingSpeedSettings.estimatedMinutes(wordCount: words, wpm: effectiveWPM)
    }

    func openInBrowser(candidate: ArticleCandidate) async {
        linkNotice = nil
        let primary = [candidate]
        let fallbackList = result.backups.filter { $0.id != candidate.id }
        let candidates = primary + fallbackList

        for (index, item) in candidates.enumerated() {
            guard let url = URL(string: item.url) else { continue }
            let reachable = await isReachable(url: url)
            if reachable {
                presentedURLItem = PresentedURL(url: url)
                if index > 0 {
                    linkNotice = "Primary link was unavailable, opened a backup source."
                }
                return
            }
        }

        errorMessage = "Could not open this article right now."
    }

    private func isReachable(url: URL) async -> Bool {
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 6

        do {
            let (_, response) = try await session.data(for: headRequest)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                return true
            }
        } catch {
        }

        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.timeoutInterval = 6

        do {
            let (_, response) = try await session.data(for: getRequest)
            if let http = response as? HTTPURLResponse {
                return (200...399).contains(http.statusCode)
            }
            return true
        } catch {
            return false
        }
    }
}

struct PresentedURL: Identifiable {
    let id = UUID()
    let url: URL
}
