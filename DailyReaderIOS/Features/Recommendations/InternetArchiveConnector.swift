import Foundation

struct InternetArchiveConnector: RecommendationsConnector {
    let source: RecommendationSource = .internetArchive
    private let http = ConnectorHTTPClient()

    func fetchCandidates(query: String, language: String) async throws -> [ArticleCandidate] {
        var comps = URLComponents(string: "https://archive.org/advancedsearch.php")
        comps?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "description"),
            URLQueryItem(name: "rows", value: "10"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "output", value: "json")
        ]
        guard let url = comps?.url else { throw ConnectorError.badURL }

        let data = try await http.data(from: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let response = object?["response"] as? [String: Any]
        let docs = response?["docs"] as? [[String: Any]] ?? []

        return docs.compactMap { doc in
            guard let identifier = doc["identifier"] as? String,
                  let title = doc["title"] as? String
            else { return nil }

            let description = parseDescription(doc["description"]) ?? ""
            return ArticleCandidate(
                id: "archive-\(identifier)",
                title: title,
                url: "https://archive.org/details/\(identifier)",
                source: .internetArchive,
                date: nil,
                snippet: description,
                licenseType: .varies,
                language: language,
                wordCount: nil,
                rawLengthFields: [:],
                extractionFailed: false
            )
        }
    }

    private func parseDescription(_ raw: Any?) -> String? {
        if let string = raw as? String { return string }
        if let array = raw as? [String] { return array.first }
        return nil
    }
}
