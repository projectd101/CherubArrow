import Foundation

struct MarketEvent: Decodable {
    let ticker: String?
    let factLine: String
    let contextLine: String?
    let pctChange: Double
    let oldPrice: Double
    let newPrice: Double
    let windowMinutes: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case ticker
        case factLine = "fact_line"
        case contextLine = "context_line"
        case pctChange = "pct_change"
        case oldPrice = "old_price"
        case newPrice = "new_price"
        case windowMinutes = "window_minutes"
        case createdAt = "created_at"
    }

    /// What TTSManager should speak: the fact, then the grounded context (if any).
    var spokenText: String {
        guard let context = contextLine, !context.isEmpty else { return factLine }
        return "\(factLine) \(context)"
    }
}

private struct MarketPulseResponse: Decodable {
    let events: [MarketEvent]
    let saved: Int?
    let errors: [String]?
}

/// Pulls narrated crypto market events from the Supabase `market-pulse` edge function
/// (fetches CoinGecko prices, diffs vs last check, and has Groq explain notable moves
/// using real recent headlines as evidence — never inventing a cause).
///
/// Prototype sibling to NewsManager. Separate on purpose so market pulse and news
/// don't get mixed into one feed while this is being tested.
final class MarketPulseManager {

    private let functionURL = URL(string: "https://ivwtbebveyiqxyqmwper.supabase.co/functions/v1/market-pulse")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3RiZWJ2ZXlpcXh5cW13cGVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5Nzk0NzcsImV4cCI6MjEwNTU1NTQ3N30.1gKTXeGCqBmd7ZbY95DM9GyWWa0FjxMpUuyvXK0xiaQ"

    /// Latest events, newest first. Read on the main thread.
    private(set) var events: [MarketEvent] = []

    /// Called on the main thread whenever `events` changes.
    var onUpdate: (() -> Void)?

    private var nextIndex = 0
    private var timer: Timer?
    private var isRefreshing = false

    func start() {
        refresh()
        // Prices move fast; check every 2 minutes. The function itself only
        // narrates moves that cross each ticker's threshold, so most checks
        // are cheap (one CoinGecko call, no Groq call).
        timer = Timer.scheduledTimer(withTimeInterval: 2 * 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            var decoded: MarketPulseResponse?
            if let error = error {
                print("⚠️ Market pulse fetch failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("⚠️ Market pulse HTTP \(http.statusCode): \(body)")
            } else if let data = data {
                do {
                    decoded = try JSONDecoder().decode(MarketPulseResponse.self, from: data)
                } catch {
                    print("⚠️ Market pulse response not understood: \(error)")
                }
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                guard let decoded = decoded else { return }
                if let errors = decoded.errors, !errors.isEmpty {
                    print("⚠️ Market pulse source errors: \(errors.joined(separator: " | "))")
                }
                self.events = decoded.events
                self.nextIndex = 0
                self.onUpdate?()
            }
        }.resume()
    }

    /// Round-robins through events so repeated taps read different tickers.
    /// Returns nil if there's nothing narrated yet (e.g. no move crossed a threshold).
    func nextEventToSpeak() -> String? {
        guard !events.isEmpty else { return nil }
        let item = events[nextIndex % events.count]
        nextIndex += 1
        return item.spokenText
    }
}
