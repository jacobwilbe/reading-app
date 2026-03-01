import Foundation

protocol RecommendationsConnector {
    var source: RecommendationSource { get }
    func fetchCandidates(query: String, language: String) async throws -> [ArticleCandidate]
}

enum ConnectorError: Error {
    case badURL
    case invalidResponse
    case timeout
}

struct ConnectorHTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL, timeout: TimeInterval = 8.0) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("DailyReaderIOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ConnectorError.invalidResponse
        }
        return data
    }
}
