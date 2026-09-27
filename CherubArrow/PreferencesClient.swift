import Foundation

struct NewsSourceItem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let rssUrl: String
    var enabled: Bool
    let pollIntervalMinutes: Int?
    let category: String // "general" | "stocks" | "crypto" | "polymarket"

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, category
        case rssUrl = "rss_url"
        case pollIntervalMinutes = "poll_interval_minutes"
    }
}

struct MarketInstrumentItem: Codable, Identifiable, Equatable {
    let id: String
    let assetClass: String
    let symbol: String
    let displayName: String
    var enabled: Bool
    var moveThresholdPct: Double

    enum CodingKeys: String, CodingKey {
        case id, symbol, enabled
        case assetClass = "asset_class"
        case displayName = "display_name"
        case moveThresholdPct = "move_threshold_pct"
    }
}

struct PreferencesSnapshot {
    var newsSources: [NewsSourceItem]
    var instruments: [MarketInstrumentItem]
}

enum PreferencesError: LocalizedError {
    case server(String)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .network(let message): return message
        case .decoding: return "Couldn't understand the server's response."
        }
    }
}

/// Talks to the `preferences` Supabase Edge Function so the Preferences window
/// can list/add/toggle/remove followed news sources and market instruments
/// (crypto/stocks/Polymarket). Uses the same project + anon key NewsManager
/// and MarketPulseManager already use — this function does the validated
/// writing server-side rather than the app writing to the tables directly.
final class PreferencesClient {

    private let functionURL = URL(string: "https://ivwtbebveyiqxyqmwper.supabase.co/functions/v1/preferences")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3RiZWJ2ZXlpcXh5cW13cGVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5Nzk0NzcsImV4cCI6MjEwNTU1NTQ3N30.1gKTXeGCqBmd7ZbY95DM9GyWWa0FjxMpUuyvXK0xiaQ"

    private func call(_ body: [String: Any], completion: @escaping (Result<[String: Any], PreferencesError>) -> Void) {
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.network(error.localizedDescription))) }
                return
            }
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                DispatchQueue.main.async { completion(.failure(.decoding)) }
                return
            }
            if let errorMessage = json["error"] as? String {
                DispatchQueue.main.async { completion(.failure(.server(errorMessage))) }
                return
            }
            DispatchQueue.main.async { completion(.success(json)) }
        }.resume()
    }

    // MARK: - Reading

    func fetchAll(completion: @escaping (Result<PreferencesSnapshot, PreferencesError>) -> Void) {
        call(["action": "list"]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let json):
                guard
                    let newsData = try? JSONSerialization.data(withJSONObject: json["newsSources"] ?? []),
                    let instrumentData = try? JSONSerialization.data(withJSONObject: json["instruments"] ?? []),
                    let newsSources = try? JSONDecoder().decode([NewsSourceItem].self, from: newsData),
                    let instruments = try? JSONDecoder().decode([MarketInstrumentItem].self, from: instrumentData)
                else {
                    completion(.failure(.decoding))
                    return
                }
                completion(.success(PreferencesSnapshot(newsSources: newsSources, instruments: instruments)))
            }
        }
    }

    // MARK: - News sources

    func addNewsSource(name: String, rssUrl: String, category: String = "general", completion: @escaping (Result<Void, PreferencesError>) -> Void) {
        call(["action": "add_news_source", "name": name, "rss_url": rssUrl, "category": category]) { completion($0.map { _ in () }) }
    }

    func toggleNewsSource(id: String, enabled: Bool, completion: @escaping (Result<Void, PreferencesError>) -> Void) {
        call(["action": "toggle_news_source", "id": id, "enabled": enabled]) { completion($0.map { _ in () }) }
    }

    func removeNewsSource(id: String, completion: @escaping (Result<Void, PreferencesError>) -> Void) {
        call(["action": "remove_news_source", "id": id]) { completion($0.map { _ in () }) }
    }

    // MARK: - Market instruments

    func addInstrument(
        assetClass: String,
        symbol: String,
        displayName: String,
        moveThresholdPct: Double,
        completion: @escaping (Result<Void, PreferencesError>) -> Void
    ) {
        call([
            "action": "add_instrument",
            "asset_class": assetClass,
            "symbol": symbol,
            "display_name": displayName,
            "move_threshold_pct": moveThresholdPct,
        ]) { completion($0.map { _ in () }) }
    }

    func toggleInstrument(id: String, enabled: Bool, completion: @escaping (Result<Void, PreferencesError>) -> Void) {
        call(["action": "toggle_instrument", "id": id, "enabled": enabled]) { completion($0.map { _ in () }) }
    }

    func updateThreshold(id: String, moveThresholdPct: Double, completion: @escaping (Result<Void, PreferencesError>) -> Void) {
        call(["action": "update_instrument_threshold", "id": id, "move_threshold_pct": moveThresholdPct]) { completion($0.map { _ in () }) }
    }

    func removeInstrument(id: String, completion: @escaping (Result<Void, PreferencesError>) -> Void) {
        call(["action": "remove_instrument", "id": id]) { completion($0.map { _ in () }) }
    }
}
