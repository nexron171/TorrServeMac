import Foundation

enum TorrAPIError: Error, LocalizedError {
    case invalidURL
    case serverError(String)
    case decodingError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError(let msg): return "Server error: \(msg)"
        case .decodingError(let msg): return "Decode error: \(msg)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

class TorrAPI {
    static let shared = TorrAPI()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private func makeRequest(_ path: String, method: String = "POST", body: [String: Any]? = nil) throws -> URLRequest {
        let settings = AppSettings.shared
        guard let url = URL(string: "\(settings.baseURL)\(path)") else {
            throw TorrAPIError.invalidURL
        }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = method

        if settings.useAuth && !settings.authLogin.isEmpty {
            let creds = "\(settings.authLogin):\(settings.authPassword)"
            if let data = creds.data(using: .utf8) {
                req.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return req
    }

    private func perform(_ path: String, method: String = "POST", body: [String: Any]? = nil) async throws -> Data {
        let req = try makeRequest(path, method: method, body: body)
        do {
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                throw TorrAPIError.serverError(msg)
            }
            return data
        } catch let err as TorrAPIError {
            throw err
        } catch {
            throw TorrAPIError.networkError(error)
        }
    }

    func echo() async throws -> String {
        let data = try await perform("/echo", method: "GET")
        return String(data: data, encoding: .utf8) ?? ""
    }

    func listTorrents() async throws -> [Torrent] {
        let data = try await perform("/torrents", body: ["action": "list"])
        do {
            return try JSONDecoder().decode([Torrent].self, from: data)
        } catch {
            throw TorrAPIError.decodingError(error.localizedDescription)
        }
    }

    func getTorrent(hash: String) async throws -> Torrent {
        let data = try await perform("/torrents", body: ["action": "get", "hash": hash])
        return try JSONDecoder().decode(Torrent.self, from: data)
    }

    func addTorrent(link: String, title: String = "", poster: String = "", category: String = "") async throws -> Torrent {
        var body: [String: Any] = ["action": "add", "link": link, "save_to_db": true]
        if !title.isEmpty { body["title"] = title }
        if !poster.isEmpty { body["poster"] = poster }
        if !category.isEmpty { body["category"] = category }

        let data = try await perform("/torrents", body: body)
        do {
            return try JSONDecoder().decode(Torrent.self, from: data)
        } catch {
            throw TorrAPIError.decodingError(error.localizedDescription)
        }
    }

    func removeTorrent(hash: String) async throws {
        _ = try await perform("/torrents", body: ["action": "rem", "hash": hash])
    }

    func dropTorrent(hash: String) async throws {
        _ = try await perform("/torrents", body: ["action": "drop", "hash": hash])
    }

    func getSettings() async throws -> BTSets {
        let data = try await perform("/settings", body: ["action": "get"])
        return try JSONDecoder().decode(BTSets.self, from: data)
    }

    func setSettings(_ sets: BTSets) async throws {
        let encoder = JSONEncoder()
        let setsData = try encoder.encode(sets)
        guard var dict = try JSONSerialization.jsonObject(with: setsData) as? [String: Any] else {
            throw TorrAPIError.decodingError("Cannot serialize settings")
        }
        dict["action"] = "set"
        _ = try await perform("/settings", body: dict)
    }

    func uploadTorrent(fileURL: URL, title: String = "", poster: String = "", category: String = "") async throws -> Torrent {
        let settings = AppSettings.shared
        guard let url = URL(string: "\(settings.baseURL)/torrent/upload") else {
            throw TorrAPIError.invalidURL
        }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if settings.useAuth && !settings.authLogin.isEmpty {
            let creds = "\(settings.authLogin):\(settings.authPassword)"
            if let data = creds.data(using: .utf8) {
                req.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()

        func append(_ string: String) {
            if let d = string.data(using: .utf8) { body.append(d) }
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        append("Content-Type: application/x-bittorrent\r\n\r\n")
        body.append(fileData)
        append("\r\n")

        for (name, value) in [("title", title), ("poster", poster), ("category", category)] where !value.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        append("--\(boundary)--\r\n")
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw TorrAPIError.serverError(msg)
        }
        return try JSONDecoder().decode(Torrent.self, from: data)
    }

    func streamURL(hash: String, fileID: Int, filename: String) -> URL? {
        let settings = AppSettings.shared
        let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filename
        return URL(string: "\(settings.baseURL)/stream/\(encoded)?link=\(hash)&index=\(fileID)&play")
    }

    func m3uURL(hash: String, name: String) -> URL? {
        let settings = AppSettings.shared
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "\(settings.baseURL)/playlist/\(encoded).m3u?hash=\(hash)")
    }

    func allM3uURL() -> URL? {
        URL(string: "\(AppSettings.shared.baseURL)/playlistall/all.m3u")
    }

    func resetSettings() async throws -> BTSets {
        let data = try await perform("/settings", body: ["action": "def"])
        return try JSONDecoder().decode(BTSets.self, from: data)
    }
}
