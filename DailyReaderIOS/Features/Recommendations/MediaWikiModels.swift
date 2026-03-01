import Foundation

struct MediaWikiSearchResponse: Codable {
    let query: QueryContainer

    struct QueryContainer: Codable {
        let search: [SearchItem]
    }

    struct SearchItem: Codable {
        let pageid: Int
        let title: String
        let snippet: String
    }
}

extension String {
    func strippingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
