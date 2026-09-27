import Foundation

struct NewsHeadline: Decodable {
    let headline: String
    let summary: String
    let source: String?
    let url: String?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case headline, summary, source, url
        case publishedAt = "published_at"
    }
}

private struct NewsResponse: Decodable {
    let headlines: [NewsHeadline]
    let errors: [String]?
}

/// Pulls short AI-written news summaries from the Supabase `news` edge function
/// (which fetches the RSS feeds in `news_sources`, has Groq summarize new items,
/// and saves them to `news_headlines`). The app never sees the Groq key.
final class NewsManager {

    // The anon key is a public, client-side key — safe to ship in the app.
    private let functionURL = URL(string: "https://ivwtbebveyiqxyqmwper.supabase.co/functions/v1/news")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3RiZWJ2ZXlpcXh5cW13cGVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5Nzk0NzcsImV4cCI6MjEwNTU1NTQ3N30.1gKTXeGCqBmd7ZbY95DM9GyWWa0FjxMpUuyvXK0xiaQ"

    /// Latest headlines, newest first. Read on the main thread.
    private(set) var headlines: [NewsHeadline] = []

    /// Called on the main thread whenever `headlines` changes.
    var onUpdate: (() -> Void)?

    private var nextIndex = 0
    private var timer: Timer?
    private var isRefreshing = false

    func start() {
        refresh()
        // The function itself only re-fetches feeds when their poll interval has elapsed,
        // so calling this every 20 minutes is cheap.
        timer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90 // first run fetches feeds + waits on Groq
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            var decoded: NewsResponse?
            if let error = error {
                print("⚠️ News fetch failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("⚠️ News fetch HTTP \(http.statusCode): \(body)")
            } else if let data = data {
                do {
                    decoded = try JSONDecoder().decode(NewsResponse.self, from: data)
                } catch {
                    print("⚠️ News response not understood: \(error)")
                }
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                guard let decoded = decoded else { return }
                if let errors = decoded.errors, !errors.isEmpty {
                    print("⚠️ News source errors: \(errors.joined(separator: " | "))")
                }
                self.headlines = decoded.headlines
                self.nextIndex = 0
                self.onUpdate?()
            }
        }.resume()
    }

    /// Round-robins through the summaries so repeated clicks read different stories.
    func nextSummaryToSpeak() -> String? {
        guard !headlines.isEmpty else { return nil }
        let item = headlines[nextIndex % headlines.count]
        nextIndex += 1
        return item.summary
    }
}
