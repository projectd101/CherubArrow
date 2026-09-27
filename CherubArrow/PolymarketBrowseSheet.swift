import SwiftUI

// MARK: - Follow-a-market sheet
// Replaces blind slug-typing for Polymarket: fetches real trending events
// from Polymarket's public Gamma API (see PolymarketAPI.swift — no key
// needed) so people can search by title and see the live Yes probability
// before following, same experience as picking a stock or coin from the
// Stocks/Crypto catalogs.

struct PolymarketBrowseSheet: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var events: [PolymarketEvent] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var query = ""
    @State private var followingSlug: String?
    @State private var showManualEntry = false

    private var filtered: [PolymarketEvent] {
        guard !query.isEmpty else { return events }
        return events.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Follow a market").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    Task { await load(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Refresh trending markets")
                Button("Cancel") { dismiss() }
            }

            TextField("Search trending markets…", text: $query)
                .textFieldStyle(.roundedBorder)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if let loadError {
                Text(loadError)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if filtered.isEmpty {
                Text("No trending markets match \u{201c}\(query)\u{201d}.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(filtered) { event in
                            row(for: event)
                        }
                    }
                }
                .frame(height: 340)
            }

            Button(showManualEntry ? "Hide manual entry" : "Can't find it? Enter a slug manually") {
                showManualEntry.toggle()
            }
            .font(.system(size: 11.5))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            if showManualEntry {
                ManualSlugEntry(viewModel: viewModel, onFollowed: { dismiss() })
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(width: 440)
        .task { await load() }
    }

    private func row(for event: PolymarketEvent) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(2)
                if let vol = event.volume24hr {
                    Text("$\(formatted(vol)) 24h volume")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let p = event.yesProbability {
                Text("\(Int((p * 100).rounded()))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(p >= 0.5 ? Color.green : Color.red)
            }
            Button(followingSlug == event.slug ? "Adding…" : "Follow") {
                followingSlug = event.slug
                viewModel.addInstrument(
                    assetClass: "polymarket",
                    symbol: event.slug,
                    displayName: event.title,
                    threshold: 5.0
                ) { success in
                    followingSlug = nil
                    if success { dismiss() }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(followingSlug != nil)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private func load(forceRefresh: Bool = false) async {
        if events.isEmpty || forceRefresh { isLoading = true }
        do {
            events = try await PolymarketAPI.fetchTrending(forceRefresh: forceRefresh)
            loadError = nil
        } catch {
            loadError = "Couldn't load trending markets — check your connection."
        }
        isLoading = false
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

/// Live-populated Polymarket catalog for the tab itself — since active
/// events churn daily this isn't a static list like StockCatalog/
/// CryptoCatalog, it's fetched fresh from Polymarket's public Gamma API
/// each time the tab appears (see PolymarketAPI.swift). Mirrors what
/// CryptoChipsSection/StockChipsSection already do: the whole tab is
/// browsable and followable without opening a sheet.
struct TrendingPolymarketSection: View {
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var events: [PolymarketEvent] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Trending Markets")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.6)
                }
            }

            if let loadError {
                Text(loadError).font(.system(size: 12)).foregroundStyle(.secondary)
            } else if events.isEmpty && !isLoading {
                Text("No trending markets right now.").font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 9) {
                    ForEach(events) { event in
                        TrendingEventCard(event: event, viewModel: viewModel)
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .task { await load() }
    }

    private func load() async {
        // Only show a spinner when there's nothing on screen yet. On a warm
        // cache this returns near-instantly and the list simply updates in
        // place, so switching tabs repeatedly doesn't re-flash a loading
        // state every time.
        if events.isEmpty { isLoading = true }
        do {
            events = try await PolymarketAPI.fetchTrending()
            loadError = nil
        } catch {
            loadError = "Couldn't load trending markets — check your connection."
        }
        isLoading = false
    }
}

/// One trending event, laid out like EventRow (icon + title + inline
/// follow/following toggle) but driven by a live PolymarketEvent instead of
/// an already-followed MarketInstrumentItem.
private struct TrendingEventCard: View {
    let event: PolymarketEvent
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var isSubmitting = false
    @State private var isHoveringFollowing = false

    private var followedItem: MarketInstrumentItem? {
        viewModel.instruments(for: "polymarket").first { $0.symbol.lowercased() == event.slug.lowercased() }
    }
    private var isFollowing: Bool { followedItem?.enabled ?? false }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.3))
                if event.isExpired {
                    Image(systemName: "clock.badge.xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                } else if let p = event.yesProbability {
                    Text("\(Int((p * 100).rounded()))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(p >= 0.5
                            ? Color(red: 0.30, green: 0.78, blue: 0.45)
                            : Color(red: 0.90, green: 0.40, blue: 0.40))
                } else {
                    Image(systemName: "questionmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                if let vol = event.volume24hr {
                    Text("$\(formatted(vol)) 24h volume").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)

            Button {
                guard !isSubmitting else { return }
                if let followedItem {
                    isSubmitting = true
                    viewModel.toggleInstrument(followedItem)
                    // toggleInstrument has no completion callback, so this
                    // just clears the brief tap-feedback state.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isSubmitting = false }
                } else {
                    isSubmitting = true
                    viewModel.addInstrument(
                        assetClass: "polymarket",
                        symbol: event.slug,
                        displayName: event.title,
                        threshold: 5.0
                    ) { _ in isSubmitting = false }
                }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().scaleEffect(0.6)
                    } else if isFollowing {
                        Text(isHoveringFollowing ? "Unfollow" : "Following")
                            .foregroundStyle(isHoveringFollowing ? Color.red : Color.white)
                    } else {
                        Text("Follow").foregroundStyle(Color.white)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .frame(minWidth: 64)
                .background(
                    Group {
                        if isFollowing {
                            Capsule()
                                .strokeBorder(isHoveringFollowing ? Color.red.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1)
                                .background(Capsule().fill(Color.black.opacity(0.35)))
                        } else {
                            // Explicit accent blue, not Color.primary — this
                            // card sits on a dark background regardless of
                            // system light/dark mode, and Color.primary can
                            // resolve to white here, producing invisible
                            // white-on-white "Follow" text.
                            Capsule().fill(Color(red: 0.302, green: 0.522, blue: 0.988))
                        }
                    }
                )
                .opacity(isSubmitting ? 0.6 : 1.0)
                .scaleEffect(isSubmitting ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSubmitting)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringFollowing = isFollowing && $0 }
            .disabled(isSubmitting)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    private func formatted(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

/// Fallback for a market that isn't in the top-60-by-volume trending page —
/// same "type the exact slug" flow as before, just demoted to a secondary
/// path instead of the only path.
private struct ManualSlugEntry: View {
    @ObservedObject var viewModel: PreferencesViewModel
    var onFollowed: () -> Void

    @State private var slug = ""
    @State private var displayName = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Polymarket slug").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("will-fed-cut-rates-q4-2026", text: $slug).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Display name").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("Fed cuts rates in Q4 2026", text: $displayName).textFieldStyle(.roundedBorder)
            }
            Button(isSubmitting ? "Adding…" : "Follow this slug") {
                isSubmitting = true
                viewModel.addInstrument(
                    assetClass: "polymarket",
                    symbol: slug,
                    displayName: displayName,
                    threshold: 5.0
                ) { success in
                    isSubmitting = false
                    if success { onFollowed() }
                }
            }
            .buttonStyle(.bordered)
            .disabled(slug.isEmpty || displayName.isEmpty || isSubmitting)
        }
    }
}
