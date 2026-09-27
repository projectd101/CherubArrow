import Foundation

// MARK: - Polymarket public API client (Gamma)
// https://docs.polymarket.com/market-data/overview — no API key, no auth,
// no wallet required. Two things this powers:
//   1. Browsing/searching real events to follow (PolymarketBrowseSheet),
//      replacing typing a raw slug blind.
//   2. A live probability read on each already-followed event's EventRow —
//      independent of whatever backend job eventually does the
//      threshold-cross alert (see note at the bottom of this file).

struct PolymarketEvent: Identifiable, Codable {
    let id: String
    let slug: String
    let title: String
    let image: String?
    let volume24hr: Double?
    let endDate: String?         // ISO-8601, e.g. "2026-12-31T12:00:00Z"
    let markets: [PolymarketMarket]?

    /// The event's headline probability — the first market's first outcome
    /// (almost always "Yes") as a 0...1 probability. `nil` if the event has
    /// no markets yet or prices aren't set.
    var yesProbability: Double? {
        markets?.first?.outcomePricesParsed?.first
    }

    /// True once `endDate` has passed. Gamma's `closed` flag can lag behind
    /// the actual resolution date, so this is checked independently rather
    /// than trusting `closed=false` in the query alone.
    var isExpired: Bool {
        guard let endDate, let date = Self.isoFormatter.date(from: endDate) else { return false }
        return date < Date()
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Whether this event is worth surfacing at all: not expired, and its
    /// headline probability is real and non-trivial. Rounds-to-zero markets
    /// (sub-1% or sub-1%-from-certain long-shots) and events with no usable
    /// price data are excluded — see PolymarketBrowseSheet chat history for
    /// why 0%/100% chips were showing up.
    var isDisplayable: Bool {
        guard !isExpired, let p = yesProbability else { return false }
        return p > 0.01 && p < 0.99
    }
}

struct PolymarketMarket: Codable {
    let question: String?
    let outcomes: String?        // JSON-encoded, e.g. "[\"Yes\",\"No\"]"
    let outcomePrices: String?   // JSON-encoded, e.g. "[\"0.62\",\"0.38\"]"
    let clobTokenIds: String?    // JSON-encoded, e.g. "[\"123...\",\"456...\"]"
    let volume24hr: Double?

    var outcomePricesParsed: [Double]? {
        guard let outcomePrices, let data = outcomePrices.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data).compactMap(Double.init)
    }
}

enum PolymarketAPI {
    private static let base = "https://gamma-api.polymarket.com"

    /// Trending/most-active events, for the browse sheet and the Polymarket
    /// tab. Cached on disk for `cacheTTL` (24h): both callers hit this same
    /// function, and neither should trigger a network fetch just because
    /// the user switched tabs and came back — only the first load of the
    /// day (or an explicit pull-to-refresh, if one gets added later) should
    /// actually hit the network.
    ///
    /// The documented server-side search is `/public-search`, but its exact
    /// query shape isn't pinned down here yet — so this pulls a larger page
    /// (default 60) and the sheet filters client-side on title, same
    /// tradeoff the static Stock/Crypto catalogs already make, just fetched
    /// live instead of hand-maintained (Polymarket's active events churn
    /// daily, hence the 24h TTL rather than something longer).
    static func fetchTrending(limit: Int = 60, forceRefresh: Bool = false) async throws -> [PolymarketEvent] {
        if !forceRefresh, let cached = TrendingCache.load(), !cached.isStale {
            return cached.events
        }

        var comps = URLComponents(string: "\(base)/events")!
        comps.queryItems = [
            .init(name: "active", value: "true"),
            .init(name: "closed", value: "false"),
            .init(name: "order", value: "volume24hr"),
            .init(name: "ascending", value: "false"),
            .init(name: "limit", value: String(limit)),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode([PolymarketEvent].self, from: data)
        let events = decoded.filter(\.isDisplayable)

        TrendingCache.save(events)
        return events
    }

    /// A single followed event by its slug (what's stored as `item.symbol`
    /// for `.poly` instruments) — used to refresh its live probability on
    /// EventRow. Not cached: this backs an already-followed item the user
    /// is actively looking at, not the browse list, so it should stay live.
    static func fetchEvent(slug: String) async throws -> PolymarketEvent? {
        var comps = URLComponents(string: "\(base)/events")!
        comps.queryItems = [.init(name: "slug", value: slug)]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try JSONDecoder().decode([PolymarketEvent].self, from: data).first
    }
}

// MARK: - On-disk trending cache
// Simple day-long cache so switching between Stocks/Crypto/Polymarket tabs
// doesn't refetch 60 events (with nested market/price parsing) on every
// visit. Written to the app's caches directory, which the OS may clear
// under disk pressure — that's fine, a cache miss just falls back to a
// normal network fetch.
private enum TrendingCache {
    private static let fileName = "polymarket_trending_cache_v2.json"
    private static let ttl: TimeInterval = 24 * 60 * 60 // 24h

    private static var fileURL: URL? {
        try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(fileName)
    }

    private struct Envelope: Codable {
        let cachedAt: Date
        let events: [PolymarketEvent]
    }

    struct Loaded {
        let events: [PolymarketEvent]
        let isStale: Bool
    }

    static func load() -> Loaded? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else { return nil }
        let isStale = Date().timeIntervalSince(envelope.cachedAt) > ttl
        return Loaded(events: envelope.events, isStale: isStale)
    }

    static func save(_ events: [PolymarketEvent]) {
        guard let url = fileURL else { return }
        let envelope = Envelope(cachedAt: Date(), events: events)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Backend note
// This file only covers client-side browsing + a live read for display.
// The actual threshold-cross alert (what makes a followed market eligible
// to be read aloud, same as stocks/crypto) needs a periodic server-side
// poll — same shape as the existing edge function that polls price for
// `stock`/`crypto` rows in market_instruments/market_prices in the
// CherubArrow Supabase project, just hitting fetchEvent(slug:)'s URL
// instead and diffing yesProbability day-over-day or run-over-run.
