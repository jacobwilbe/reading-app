import Foundation

struct ProfileStore {
    private let dataFileName = "profile-local-data.json"
    private let imageFileName = "profile-photo.jpg"

    func load() -> ProfileLocalData {
        let url = dataURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? decoder.decode(ProfileLocalData.self, from: data)
        else {
            let seeded = ProfileLocalData.seed()
            save(seeded)
            return seeded
        }

        return decoded
    }

    func save(_ payload: ProfileLocalData) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(payload)
            try data.write(to: dataURL, options: .atomic)
        } catch {
            print("ProfileStore save failed: \(error)")
        }
    }

    func saveImageData(_ data: Data) -> String? {
        let url = imageURL

        do {
            try data.write(to: url, options: .atomic)
            return url.lastPathComponent
        } catch {
            print("ProfileStore image save failed: \(error)")
            return nil
        }
    }

    func loadImageData(fromRelativePath relativePath: String?) -> Data? {
        guard let relativePath else { return nil }
        let url = documentsDirectory.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    private var dataURL: URL {
        documentsDirectory.appendingPathComponent(dataFileName)
    }

    private var imageURL: URL {
        documentsDirectory.appendingPathComponent(imageFileName)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
