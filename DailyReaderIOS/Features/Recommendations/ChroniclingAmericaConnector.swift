import Foundation

struct ChroniclingAmericaConnector: RecommendationsConnector {
    let source: RecommendationSource = .chroniclingAmerica
    private let http = ConnectorHTTPClient()

    func fetchCandidates(query: String, language: String) async throws -> [ArticleCandidate] {
        var comps = URLComponents(string: "https://chroniclingamerica.loc.gov/search/pages/results/")
        comps?.queryItems = [
            URLQueryItem(name: "andtext", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "rows", value: "10")
        ]
        guard let url = comps?.url else { throw ConnectorError.badURL }

        let data = try await http.data(from: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = object?["items"] as? [[String: Any]] ?? []

        let iso = ISO8601DateFormatter()
        return items.compactMap { item in
            let title = (item["title"] as? String) ?? (item["id"] as? String) ?? "LOC Article"
            guard let id = item["id"] as? String else { return nil }
            let snippet = (item["ocr_eng"] as? String) ?? "Historic newspaper page from the Library of Congress."
            let dateString = item["date"] as? String
            let date = dateString.flatMap { iso.date(from: $0) }

            return ArticleCandidate(
                id: "loc-\(id)",
                title: title,
                url: id,
                source: .chroniclingAmerica,
                date: date,
                snippet: String(snippet.prefix(220)),
                licenseType: .publicDomain,
                language: language,
                wordCount: nil,
                rawLengthFields: ["license_note": "Public Domain / LOC"],
                extractionFailed: false
            )
        }
    }
}
