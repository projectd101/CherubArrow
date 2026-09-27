import SwiftUI

// MARK: - Sage palette
// Soft sage-green background with deep-forest-green headline text and flat
// white rounded cards for every followable item — matches the tryBloom.xyz
// reference look rather than the earlier dark-glass theme.

private enum Sage {
    static let background = Color(red: 0.020, green: 0.043, blue: 0.098)   // #050B19 — deep navy
    static let backgroundDeep = Color(red: 0.012, green: 0.027, blue: 0.067) // near-black navy, for the sidebar
    static let forest = Color.white                                          // headline/ink is white now
    static let forestSoft = Color.white.opacity(0.62)
    static let forestFaint = Color.white.opacity(0.38)
    static let card = Color(red: 0.055, green: 0.086, blue: 0.161)          // #0E1629 — glass card fill
    static let cardBorder = Color.white.opacity(0.08)
    static let accent = Color(red: 0.302, green: 0.522, blue: 0.988)        // bright electric blue for active states
}

/// App-wide text colors on the sage background. Explicit values (not
/// .secondary/.tertiary) so contrast stays correct against a colored, not
/// neutral, background.
private enum Ink {
    static let primary = Sage.forest
    static let secondary = Sage.forestSoft
    static let tertiary = Sage.forestFaint
}

/// Flat white "content card" — every followable profile, section container,
/// and settings block uses this instead of the earlier dark glass material.
private struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Sage.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Sage.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}

private extension View {
    func glass(cornerRadius: CGFloat = 14, strong: Bool = false) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

private enum Brass {
    // Kept as the accent name used throughout the rest of the file, but now
    // mapped to the sage accent green instead of a gold/brass tone.
    static let color = Sage.accent
    static let dim = Sage.accent.opacity(0.7)
    static let gradient = LinearGradient(
        colors: [Sage.accent, Sage.accent.opacity(0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// Which top-level section is showing. Voice/Personalization/Plan replace the
/// top category tabs entirely. Stocks/Crypto/Polymarket/News all share the
/// same tab row within Home — News is a 4th tab, not a separate sidebar
/// destination, and inside it Stocks/Crypto/Polymarket appear again as three
/// stacked sections (same chip-row layout as the Stocks tab) so every
/// followed source is visible with its logo in one place instead of
/// duplicated inside each individual asset pane.
private enum Section: Hashable {
    case commodities, stocks, crypto, poly, news
    case voice, personalization, plan
}

private enum AssetCategory: String, CaseIterable {
    case commodities, stocks, crypto, poly = "polymarket", news

    var label: String {
        switch self {
        case .commodities: return "Commodities"
        case .stocks: return "Stocks"
        case .crypto: return "Crypto"
        case .poly: return "Polymarket"
        case .news: return "News"
        }
    }
    var icon: String {
        switch self {
        case .commodities: return "shippingbox.fill"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .crypto: return "bitcoinsign.circle"
        case .poly: return "chart.bar.xaxis"
        case .news: return "newspaper"
        }
    }
    /// Matches market_instruments.asset_class in the backend. Not used for
    /// `.news`, which has no instrument list of its own. Commodities
    /// piggybacks on the "stock" asset class (see StockChip), same as it did
    /// when Minerals lived inside the Stocks tab, so no backend/data change.
    var instrumentAssetClass: String {
        switch self {
        case .commodities: return "stock"
        case .stocks: return "stock"
        case .crypto: return "crypto"
        case .poly: return "polymarket"
        case .news: return ""
        }
    }
    /// Matches news_sources.category in the backend. Not used for `.news`
    /// itself (it shows all three categories at once).
    var newsCategory: String {
        switch self {
        case .commodities: return "stocks"
        case .stocks: return "stocks"
        case .crypto: return "crypto"
        case .poly: return "polymarket"
        case .news: return "stocks"
        }
    }
}

// MARK: - Stock sector lookup
// Wiring by NAME only, for now: a static ticker -> sector map used purely to
// decide which sector card a followed stock's row renders under. No live
// price/weight/market-cap data here — that can come later.

private enum StockSector: String, CaseIterable {
    case metals = "Metals"
    case indices = "Indices"
    case technology = "Technology"
    case communicationServices = "Communication Services"
    case consumerDiscretionary = "Consumer Discretionary"
    case consumerStaples = "Consumer Staples"
    case healthcare = "Healthcare"
    case financials = "Financials"
    case industrials = "Industrials"
    case energy = "Energy"
    case materials = "Materials"
    case utilities = "Utilities"
    case realEstate = "Real Estate"
    // Commodities-tab-only sectors (excluded from the Stocks tab's bySector,
    // see StockCatalog below). Kept as distinct cases from the similarly
    // named stock sectors above (.energy, .materials) so an oil future and
    // an oil *company* stock never land in the same grid.
    // Raw value must stay unique from `.energy` above (enum requirement),
    // so this uses an internal id — `displayName` below is what's shown.
    case commodityEnergy = "CommodityEnergy"
    case agriculture = "Agriculture"
    case livestock = "Livestock"
    case other = "Other"

    /// What's actually shown as the section heading. Same as `rawValue` for
    /// every sector except `.commodityEnergy`, which displays as "Energy"
    /// (matching the Stocks-tab Energy sector's label) despite needing a
    /// different raw value to satisfy Swift's uniqueness requirement.
    var displayName: String {
        self == .commodityEnergy ? "Energy" : rawValue
    }



    /// Distinct color per sector — no two sectors share a fill.
    var color: Color {
        switch self {
        case .metals:                  return Color(red: 0.95, green: 0.90, blue: 0.70) // pale gold
        case .indices:                 return Color(red: 0.87, green: 0.93, blue: 0.99) // pale sky blue
        case .technology:              return Color(red: 0.82, green: 0.90, blue: 0.99) // light blue
        case .communicationServices:   return Color(red: 0.99, green: 0.85, blue: 0.93) // pink
        case .consumerDiscretionary:   return Color(red: 1.00, green: 0.93, blue: 0.73) // amber
        case .consumerStaples:         return Color(red: 0.78, green: 0.96, blue: 0.85) // mint
        case .healthcare:              return Color(red: 0.85, green: 0.87, blue: 0.99) // periwinkle
        case .financials:              return Color(red: 0.99, green: 0.83, blue: 0.83) // salmon
        case .industrials:             return Color(red: 0.87, green: 0.87, blue: 0.90) // slate gray
        case .energy:                  return Color(red: 0.99, green: 0.83, blue: 0.66) // orange
        case .materials:               return Color(red: 0.92, green: 0.84, blue: 0.99) // lavender
        case .utilities:               return Color(red: 0.78, green: 0.96, blue: 0.93) // teal
        case .realEstate:              return Color(red: 0.98, green: 0.96, blue: 0.75) // pale yellow
        case .commodityEnergy:         return Color(red: 0.85, green: 0.82, blue: 0.78) // pale crude-black stone
        case .agriculture:             return Color(red: 0.90, green: 0.94, blue: 0.76) // pale wheat green
        case .livestock:               return Color(red: 0.96, green: 0.86, blue: 0.78) // pale terracotta
        case .other:                   return Color(red: 0.90, green: 0.90, blue: 0.90) // neutral gray
        }
    }

    /// Border/heading tint — a deeper shade of the same hue as `color`.
    var accentColor: Color {
        switch self {
        case .metals:                  return Color(red: 0.72, green: 0.58, blue: 0.10)
        case .indices:                 return Color(red: 0.15, green: 0.35, blue: 0.65)
        case .technology:              return Color(red: 0.20, green: 0.45, blue: 0.80)
        case .communicationServices:   return Color(red: 0.78, green: 0.25, blue: 0.55)
        case .consumerDiscretionary:   return Color(red: 0.75, green: 0.55, blue: 0.05)
        case .consumerStaples:         return Color(red: 0.15, green: 0.60, blue: 0.40)
        case .healthcare:              return Color(red: 0.35, green: 0.35, blue: 0.75)
        case .financials:              return Color(red: 0.75, green: 0.25, blue: 0.25)
        case .industrials:             return Color(red: 0.40, green: 0.40, blue: 0.46)
        case .energy:                  return Color(red: 0.80, green: 0.45, blue: 0.10)
        case .materials:               return Color(red: 0.55, green: 0.35, blue: 0.80)
        case .utilities:               return Color(red: 0.10, green: 0.55, blue: 0.52)
        case .realEstate:              return Color(red: 0.65, green: 0.58, blue: 0.10)
        case .commodityEnergy:         return Color(red: 0.20, green: 0.18, blue: 0.16) // near-black, crude oil
        case .agriculture:             return Color(red: 0.45, green: 0.55, blue: 0.15) // wheat-field green
        case .livestock:               return Color(red: 0.65, green: 0.35, blue: 0.20) // terracotta
        case .other:                   return Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }

    /// Lookup by ticker symbol, case-insensitive. Unknown tickers fall back
    /// to `.other` so nothing followed ever disappears from the grid.
    static func forSymbol(_ symbol: String) -> StockSector {
        Self.tickerMap[symbol.uppercased()] ?? .other
    }

    private static let tickerMap: [String: StockSector] = [
        // Metals (5)
        "XAU": .metals, "XAG": .metals, "XPT": .metals, "XPD": .metals, "HG": .metals,
        // Commodities: Energy (5)
        "CL": .commodityEnergy, "BZ": .commodityEnergy, "NG": .commodityEnergy,
        "RB": .commodityEnergy, "HO": .commodityEnergy,
        // Commodities: Agriculture (7)
        "ZC": .agriculture, "ZW": .agriculture, "ZS": .agriculture, "KC": .agriculture,
        "SB": .agriculture, "CT": .agriculture, "CC": .agriculture,
        // Commodities: Livestock (2)
        "LE": .livestock, "HE": .livestock,
        // Indices (6)
        "SPX": .indices, "NDX": .indices, "IXIC": .indices, "DJI": .indices,
        "RUT": .indices, "VIX": .indices,
        // Technology (31)
        "NVDA": .technology, "AAPL": .technology, "MSFT": .technology, "AVGO": .technology,
        "MU": .technology, "AMD": .technology, "INTC": .technology, "PLTR": .technology,
        "CSCO": .technology, "LRCX": .technology, "AMAT": .technology, "PANW": .technology,
        "SNDK": .technology, "CRWD": .technology, "ORCL": .technology, "TXN": .technology,
        "KLAC": .technology, "MRVL": .technology, "IBM": .technology, "STX": .technology,
        "ANET": .technology, "QCOM": .technology, "APH": .technology, "CRM": .technology,
        "ADI": .technology, "DELL": .technology, "WDC": .technology, "NOW": .technology,
        "GLW": .technology, "ACN": .technology, "FTNT": .technology,
        // Communication Services (6)
        "GOOGL": .communicationServices, "META": .communicationServices, "NFLX": .communicationServices, "VZ": .communicationServices,
        "DIS": .communicationServices, "T": .communicationServices,
        // Consumer Discretionary (8)
        "AMZN": .consumerDiscretionary, "TSLA": .consumerDiscretionary, "HD": .consumerDiscretionary, "MCD": .consumerDiscretionary,
        "TJX": .consumerDiscretionary, "BKNG": .consumerDiscretionary, "NKE": .consumerDiscretionary, "SBUX": .consumerDiscretionary,
        // Consumer Staples (9)
        "WMT": .consumerStaples, "COST": .consumerStaples, "PG": .consumerStaples, "KO": .consumerStaples,
        "PM": .consumerStaples, "PEP": .consumerStaples, "MO": .consumerStaples, "NESN": .consumerStaples,
        "UL": .consumerStaples,
        // Healthcare (16)
        "LLY": .healthcare, "JNJ": .healthcare, "ABBV": .healthcare, "MRK": .healthcare,
        "UNH": .healthcare, "TMO": .healthcare, "AMGN": .healthcare, "GILD": .healthcare,
        "ABT": .healthcare, "PFE": .healthcare, "ISRG": .healthcare, "DHR": .healthcare,
        "VRTX": .healthcare, "BMY": .healthcare, "MDT": .healthcare, "CVS": .healthcare,
        // Financials (16)
        "BRK-B": .financials, "JPM": .financials, "V": .financials, "MA": .financials,
        "BAC": .financials, "GS": .financials, "WFC": .financials, "MS": .financials,
        "C": .financials, "SCHW": .financials, "AXP": .financials, "BLK": .financials,
        "SPGI": .financials, "COF": .financials, "CB": .financials, "PGR": .financials,
        // Industrials (12)
        "CAT": .industrials, "GE": .industrials, "RTX": .industrials, "GEV": .industrials,
        "DE": .industrials, "ETN": .industrials, "UNP": .industrials, "BA": .industrials,
        "UBER": .industrials, "PH": .industrials, "LMT": .industrials, "NOC": .industrials,
        // Energy (5)
        "XOM": .energy, "CVX": .energy, "COP": .energy, "MPC": .energy,
        "VLO": .energy,
        // Materials (2)
        "LIN": .materials, "NEM": .materials,
        // Utilities (1)
        "NEE": .utilities,
        // Real Estate (2)
        "WELL": .realEstate, "PLD": .realEstate,
    ]
}


// MARK: Complete stock catalog — indices + a broad set of large caps across
// sectors, including several well-known non-US names (Nestlé, Unilever)
// alongside Lockheed Martin / Northrop Grumman in Industrials, Nike /
// Starbucks in Consumer Discretionary.

private struct StockCatalogItem: Identifiable, Hashable {
    let symbol: String
    let name: String
    let sector: StockSector

    var id: String { symbol }
}

private enum StockCatalog {
    static let all: [StockCatalogItem] = [
        // Metals (5)
        StockCatalogItem(symbol: "XAU", name: "Gold", sector: .metals),
        StockCatalogItem(symbol: "XAG", name: "Silver", sector: .metals),
        StockCatalogItem(symbol: "XPT", name: "Platinum", sector: .metals),
        StockCatalogItem(symbol: "XPD", name: "Palladium", sector: .metals),
        StockCatalogItem(symbol: "HG", name: "Copper", sector: .metals),
        // Commodities: Energy (5)
        StockCatalogItem(symbol: "CL", name: "WTI Crude Oil", sector: .commodityEnergy),
        StockCatalogItem(symbol: "BZ", name: "Brent Crude Oil", sector: .commodityEnergy),
        StockCatalogItem(symbol: "NG", name: "Natural Gas", sector: .commodityEnergy),
        StockCatalogItem(symbol: "RB", name: "RBOB Gasoline", sector: .commodityEnergy),
        StockCatalogItem(symbol: "HO", name: "Heating Oil", sector: .commodityEnergy),
        // Commodities: Agriculture (7)
        StockCatalogItem(symbol: "ZC", name: "Corn", sector: .agriculture),
        StockCatalogItem(symbol: "ZW", name: "Wheat", sector: .agriculture),
        StockCatalogItem(symbol: "ZS", name: "Soybeans", sector: .agriculture),
        StockCatalogItem(symbol: "KC", name: "Coffee", sector: .agriculture),
        StockCatalogItem(symbol: "SB", name: "Sugar", sector: .agriculture),
        StockCatalogItem(symbol: "CT", name: "Cotton", sector: .agriculture),
        StockCatalogItem(symbol: "CC", name: "Cocoa", sector: .agriculture),
        // Commodities: Livestock (2)
        StockCatalogItem(symbol: "LE", name: "Live Cattle", sector: .livestock),
        StockCatalogItem(symbol: "HE", name: "Lean Hogs", sector: .livestock),
        // Indices (6)
        StockCatalogItem(symbol: "SPX", name: "S&P 500", sector: .indices),
        StockCatalogItem(symbol: "NDX", name: "Nasdaq 100", sector: .indices),
        StockCatalogItem(symbol: "IXIC", name: "Nasdaq Composite", sector: .indices),
        StockCatalogItem(symbol: "DJI", name: "Dow Jones Industrial Average", sector: .indices),
        StockCatalogItem(symbol: "RUT", name: "Russell 2000", sector: .indices),
        StockCatalogItem(symbol: "VIX", name: "CBOE Volatility Index", sector: .indices),
        // Technology (31)
        StockCatalogItem(symbol: "NVDA", name: "NVIDIA", sector: .technology),
        StockCatalogItem(symbol: "AAPL", name: "Apple", sector: .technology),
        StockCatalogItem(symbol: "MSFT", name: "Microsoft", sector: .technology),
        StockCatalogItem(symbol: "AVGO", name: "Broadcom", sector: .technology),
        StockCatalogItem(symbol: "MU", name: "Micron Technology", sector: .technology),
        StockCatalogItem(symbol: "AMD", name: "Advanced Micro Devices", sector: .technology),
        StockCatalogItem(symbol: "INTC", name: "Intel", sector: .technology),
        StockCatalogItem(symbol: "PLTR", name: "Palantir Technologies", sector: .technology),
        StockCatalogItem(symbol: "CSCO", name: "Cisco Systems", sector: .technology),
        StockCatalogItem(symbol: "LRCX", name: "Lam Research", sector: .technology),
        StockCatalogItem(symbol: "AMAT", name: "Applied Materials", sector: .technology),
        StockCatalogItem(symbol: "PANW", name: "Palo Alto Networks", sector: .technology),
        StockCatalogItem(symbol: "SNDK", name: "Sandisk", sector: .technology),
        StockCatalogItem(symbol: "CRWD", name: "CrowdStrike Holdings", sector: .technology),
        StockCatalogItem(symbol: "ORCL", name: "Oracle", sector: .technology),
        StockCatalogItem(symbol: "TXN", name: "Texas Instruments", sector: .technology),
        StockCatalogItem(symbol: "KLAC", name: "KLA", sector: .technology),
        StockCatalogItem(symbol: "MRVL", name: "Marvell Technology", sector: .technology),
        StockCatalogItem(symbol: "IBM", name: "International Business Machines", sector: .technology),
        StockCatalogItem(symbol: "STX", name: "Seagate Technology Holdings", sector: .technology),
        StockCatalogItem(symbol: "ANET", name: "Arista Networks", sector: .technology),
        StockCatalogItem(symbol: "QCOM", name: "QUALCOMM", sector: .technology),
        StockCatalogItem(symbol: "APH", name: "Amphenol", sector: .technology),
        StockCatalogItem(symbol: "CRM", name: "Salesforce", sector: .technology),
        StockCatalogItem(symbol: "ADI", name: "Analog Devices", sector: .technology),
        StockCatalogItem(symbol: "DELL", name: "Dell Technologies", sector: .technology),
        StockCatalogItem(symbol: "WDC", name: "Western Digital", sector: .technology),
        StockCatalogItem(symbol: "NOW", name: "ServiceNow", sector: .technology),
        StockCatalogItem(symbol: "GLW", name: "Corning", sector: .technology),
        StockCatalogItem(symbol: "ACN", name: "Accenture", sector: .technology),
        StockCatalogItem(symbol: "FTNT", name: "Fortinet", sector: .technology),
        // Communication Services (6)
        StockCatalogItem(symbol: "GOOGL", name: "Alphabet", sector: .communicationServices),
        StockCatalogItem(symbol: "META", name: "Meta Platforms", sector: .communicationServices),
        StockCatalogItem(symbol: "NFLX", name: "Netflix", sector: .communicationServices),
        StockCatalogItem(symbol: "VZ", name: "Verizon Communications", sector: .communicationServices),
        StockCatalogItem(symbol: "DIS", name: "Walt Disney", sector: .communicationServices),
        StockCatalogItem(symbol: "T", name: "AT&T", sector: .communicationServices),
        // Consumer Discretionary (8)
        StockCatalogItem(symbol: "AMZN", name: "Amazon.com", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "TSLA", name: "Tesla", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "HD", name: "Home Depot", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "MCD", name: "McDonald's", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "TJX", name: "TJX Companies", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "BKNG", name: "Booking Holdings", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "NKE", name: "Nike", sector: .consumerDiscretionary),
        StockCatalogItem(symbol: "SBUX", name: "Starbucks", sector: .consumerDiscretionary),
        // Consumer Staples (9)
        StockCatalogItem(symbol: "WMT", name: "Walmart", sector: .consumerStaples),
        StockCatalogItem(symbol: "COST", name: "Costco Wholesale", sector: .consumerStaples),
        StockCatalogItem(symbol: "PG", name: "Procter & Gamble", sector: .consumerStaples),
        StockCatalogItem(symbol: "KO", name: "Coca-Cola", sector: .consumerStaples),
        StockCatalogItem(symbol: "PM", name: "Philip Morris International", sector: .consumerStaples),
        StockCatalogItem(symbol: "PEP", name: "PepsiCo", sector: .consumerStaples),
        StockCatalogItem(symbol: "MO", name: "Altria Group", sector: .consumerStaples),
        StockCatalogItem(symbol: "NESN", name: "Nestlé", sector: .consumerStaples),
        StockCatalogItem(symbol: "UL", name: "Unilever", sector: .consumerStaples),
        // Healthcare (16)
        StockCatalogItem(symbol: "LLY", name: "Eli Lilly", sector: .healthcare),
        StockCatalogItem(symbol: "JNJ", name: "Johnson & Johnson", sector: .healthcare),
        StockCatalogItem(symbol: "ABBV", name: "AbbVie", sector: .healthcare),
        StockCatalogItem(symbol: "MRK", name: "Merck", sector: .healthcare),
        StockCatalogItem(symbol: "UNH", name: "UnitedHealth Group", sector: .healthcare),
        StockCatalogItem(symbol: "TMO", name: "Thermo Fisher Scientific", sector: .healthcare),
        StockCatalogItem(symbol: "AMGN", name: "Amgen", sector: .healthcare),
        StockCatalogItem(symbol: "GILD", name: "Gilead Sciences", sector: .healthcare),
        StockCatalogItem(symbol: "ABT", name: "Abbott Laboratories", sector: .healthcare),
        StockCatalogItem(symbol: "PFE", name: "Pfizer", sector: .healthcare),
        StockCatalogItem(symbol: "ISRG", name: "Intuitive Surgical", sector: .healthcare),
        StockCatalogItem(symbol: "DHR", name: "Danaher", sector: .healthcare),
        StockCatalogItem(symbol: "VRTX", name: "Vertex Pharmaceuticals", sector: .healthcare),
        StockCatalogItem(symbol: "BMY", name: "Bristol-Myers Squibb", sector: .healthcare),
        StockCatalogItem(symbol: "MDT", name: "Medtronic plc.", sector: .healthcare),
        StockCatalogItem(symbol: "CVS", name: "CVS Health", sector: .healthcare),
        // Financials (16)
        StockCatalogItem(symbol: "BRK-B", name: "Berkshire Hathaway", sector: .financials),
        StockCatalogItem(symbol: "JPM", name: "JPMorgan Chase", sector: .financials),
        StockCatalogItem(symbol: "V", name: "Visa", sector: .financials),
        StockCatalogItem(symbol: "MA", name: "Mastercard", sector: .financials),
        StockCatalogItem(symbol: "BAC", name: "Bank of America", sector: .financials),
        StockCatalogItem(symbol: "GS", name: "Goldman Sachs Group", sector: .financials),
        StockCatalogItem(symbol: "WFC", name: "Wells Fargo", sector: .financials),
        StockCatalogItem(symbol: "MS", name: "Morgan Stanley", sector: .financials),
        StockCatalogItem(symbol: "C", name: "Citigroup", sector: .financials),
        StockCatalogItem(symbol: "SCHW", name: "Charles Schwab", sector: .financials),
        StockCatalogItem(symbol: "AXP", name: "American Express", sector: .financials),
        StockCatalogItem(symbol: "BLK", name: "BlackRock", sector: .financials),
        StockCatalogItem(symbol: "SPGI", name: "S&P Global", sector: .financials),
        StockCatalogItem(symbol: "COF", name: "Capital One Financial", sector: .financials),
        StockCatalogItem(symbol: "CB", name: "Chubb", sector: .financials),
        StockCatalogItem(symbol: "PGR", name: "Progressive", sector: .financials),
        // Industrials (12)
        StockCatalogItem(symbol: "CAT", name: "Caterpillar", sector: .industrials),
        StockCatalogItem(symbol: "GE", name: "GE Aerospace", sector: .industrials),
        StockCatalogItem(symbol: "RTX", name: "RTX", sector: .industrials),
        StockCatalogItem(symbol: "GEV", name: "GE Vernova", sector: .industrials),
        StockCatalogItem(symbol: "DE", name: "Deere", sector: .industrials),
        StockCatalogItem(symbol: "ETN", name: "Eaton", sector: .industrials),
        StockCatalogItem(symbol: "UNP", name: "Union Pacific", sector: .industrials),
        StockCatalogItem(symbol: "BA", name: "Boeing", sector: .industrials),
        StockCatalogItem(symbol: "UBER", name: "Uber Technologies", sector: .industrials),
        StockCatalogItem(symbol: "PH", name: "Parker-Hannifin", sector: .industrials),
        StockCatalogItem(symbol: "LMT", name: "Lockheed Martin", sector: .industrials),
        StockCatalogItem(symbol: "NOC", name: "Northrop Grumman", sector: .industrials),
        // Energy (5)
        StockCatalogItem(symbol: "XOM", name: "Exxon Mobil", sector: .energy),
        StockCatalogItem(symbol: "CVX", name: "Chevron", sector: .energy),
        StockCatalogItem(symbol: "COP", name: "ConocoPhillips", sector: .energy),
        StockCatalogItem(symbol: "MPC", name: "Marathon Petroleum", sector: .energy),
        StockCatalogItem(symbol: "VLO", name: "Valero Energy", sector: .energy),
        // Materials (2)
        StockCatalogItem(symbol: "LIN", name: "Linde", sector: .materials),
        StockCatalogItem(symbol: "NEM", name: "Newmont", sector: .materials),
        // Utilities (1)
        StockCatalogItem(symbol: "NEE", name: "NextEra Energy", sector: .utilities),
        // Real Estate (2)
        StockCatalogItem(symbol: "WELL", name: "Welltower", sector: .realEstate),
        StockCatalogItem(symbol: "PLD", name: "Prologis", sector: .realEstate),
    ]

    /// Sectors that live only under the Commodities tab, not Stocks —
    /// excluded from `bySector` below and drawn from by `commodities`, in
    /// the order they should appear (Energy, then Metals, then softs).
    private static let commoditySectors: [StockSector] = [.commodityEnergy, .metals, .agriculture, .livestock]

    /// Stocks tab: every equity/index sector — excludes `.other` and the
    /// commodity-only sectors, which now live under their own Commodities
    /// tab (see `commodities` below).
    static var bySector: [(sector: StockSector, items: [StockCatalogItem])] {
        let commoditySet = Set(commoditySectors)
        return StockSector.allCases
            .filter { $0 != .other && !commoditySet.contains($0) }
            .compactMap { sector in
                let items = all.filter { $0.sector == sector }
                return items.isEmpty ? nil : (sector: sector, items: items)
            }
    }

    /// Commodities tab: Energy (oil/gas), Metals (precious + industrial),
    /// Agriculture (grains/softs), and Livestock — in that order. Same
    /// chip-row rendering as Stocks, just its own tab.
    static var commodities: [(sector: StockSector, items: [StockCatalogItem])] {
        commoditySectors.compactMap { sector in
            let items = all.filter { $0.sector == sector }
            return items.isEmpty ? nil : (sector: sector, items: items)
        }
    }
}

// MARK: - Crypto catalog
// Same static-catalog / sector-chip pattern as Stocks and Commodities: a
// curated top-cryptos list grouped into categories, rendered as bare chip
// rows (no "Live Updates" header, no Follow-sheet) via CryptoChipsSection.

private enum CryptoSector: String, CaseIterable {
    case layer1 = "Layer 1"
    case layer2 = "Layer 2"
    case defi = "DeFi"
    case exchangeTokens = "Exchange Tokens"
    case stablecoins = "Stablecoins"
    case memeCoins = "Meme Coins"

    var color: Color {
        switch self {
        case .layer1:          return Color(red: 0.83, green: 0.87, blue: 0.99) // periwinkle
        case .layer2:          return Color(red: 0.78, green: 0.95, blue: 0.92) // teal
        case .defi:            return Color(red: 0.97, green: 0.85, blue: 0.95) // pink
        case .exchangeTokens:  return Color(red: 1.00, green: 0.92, blue: 0.70) // amber
        case .stablecoins:     return Color(red: 0.80, green: 0.96, blue: 0.85) // mint
        case .memeCoins:       return Color(red: 1.00, green: 0.90, blue: 0.70) // orange
        }
    }
    var accentColor: Color {
        switch self {
        case .layer1:          return Color(red: 0.25, green: 0.35, blue: 0.85)
        case .layer2:          return Color(red: 0.10, green: 0.55, blue: 0.50)
        case .defi:            return Color(red: 0.70, green: 0.20, blue: 0.55)
        case .exchangeTokens:  return Color(red: 0.75, green: 0.55, blue: 0.05)
        case .stablecoins:     return Color(red: 0.15, green: 0.60, blue: 0.40)
        case .memeCoins:       return Color(red: 0.85, green: 0.50, blue: 0.10)
        }
    }

    static func forSymbol(_ symbol: String) -> CryptoSector {
        CryptoCatalog.all.first { $0.symbol.uppercased() == symbol.uppercased() }?.sector ?? .layer1
    }
}

private struct CryptoCatalogItem: Identifiable, Hashable {
    let symbol: String
    let name: String
    let sector: CryptoSector
    var id: String { symbol }
}

private enum CryptoCatalog {
    static let all: [CryptoCatalogItem] = [
        // Layer 1 (12)
        CryptoCatalogItem(symbol: "BTC", name: "Bitcoin", sector: .layer1),
        CryptoCatalogItem(symbol: "ETH", name: "Ethereum", sector: .layer1),
        CryptoCatalogItem(symbol: "SOL", name: "Solana", sector: .layer1),
        CryptoCatalogItem(symbol: "ADA", name: "Cardano", sector: .layer1),
        CryptoCatalogItem(symbol: "AVAX", name: "Avalanche", sector: .layer1),
        CryptoCatalogItem(symbol: "TRX", name: "TRON", sector: .layer1),
        CryptoCatalogItem(symbol: "TON", name: "Toncoin", sector: .layer1),
        CryptoCatalogItem(symbol: "DOT", name: "Polkadot", sector: .layer1),
        CryptoCatalogItem(symbol: "NEAR", name: "NEAR Protocol", sector: .layer1),
        CryptoCatalogItem(symbol: "APT", name: "Aptos", sector: .layer1),
        CryptoCatalogItem(symbol: "SUI", name: "Sui", sector: .layer1),
        CryptoCatalogItem(symbol: "ATOM", name: "Cosmos", sector: .layer1),
        // Layer 2 (3)
        CryptoCatalogItem(symbol: "MATIC", name: "Polygon", sector: .layer2),
        CryptoCatalogItem(symbol: "ARB", name: "Arbitrum", sector: .layer2),
        CryptoCatalogItem(symbol: "OP", name: "Optimism", sector: .layer2),
        // DeFi (4)
        CryptoCatalogItem(symbol: "UNI", name: "Uniswap", sector: .defi),
        CryptoCatalogItem(symbol: "LINK", name: "Chainlink", sector: .defi),
        CryptoCatalogItem(symbol: "AAVE", name: "Aave", sector: .defi),
        CryptoCatalogItem(symbol: "MKR", name: "Maker", sector: .defi),
        // Exchange Tokens (1)
        CryptoCatalogItem(symbol: "BNB", name: "BNB", sector: .exchangeTokens),
        // Stablecoins (3)
        CryptoCatalogItem(symbol: "USDT", name: "Tether", sector: .stablecoins),
        CryptoCatalogItem(symbol: "USDC", name: "USD Coin", sector: .stablecoins),
        CryptoCatalogItem(symbol: "DAI", name: "Dai", sector: .stablecoins),
        // Meme Coins (3)
        CryptoCatalogItem(symbol: "DOGE", name: "Dogecoin", sector: .memeCoins),
        CryptoCatalogItem(symbol: "SHIB", name: "Shiba Inu", sector: .memeCoins),
        CryptoCatalogItem(symbol: "PEPE", name: "Pepe", sector: .memeCoins),
    ]

    /// Declaration order of CryptoSector already reads Layer 1 → Layer 2 →
    /// DeFi → Exchange Tokens → Stablecoins → Meme Coins, so bySector just
    /// follows allCases like Stocks does.
    static var bySector: [(sector: CryptoSector, items: [CryptoCatalogItem])] {
        CryptoSector.allCases.compactMap { sector in
            let items = all.filter { $0.sector == sector }
            return items.isEmpty ? nil : (sector: sector, items: items)
        }
    }
}

// MARK: - Company logos
// Pulled from Clearbit's free logo CDN (logo.clearbit.com/{domain}) via
// AsyncImage — no bundled image assets and no API key needed. Falls back to
// a monogram badge if a domain is missing or a fetch fails (offline, no
// network entitlement, rate-limited, etc).

private enum CompanyDomains {
    static func domain(for symbol: String) -> String? {
        map[symbol.uppercased()]
    }

    private static let map: [String: String] = [
        // Indices
        "SPX": "spglobal.com", "NDX": "nasdaq.com", "IXIC": "nasdaq.com",
        "DJI": "dowjones.com", "RUT": "ftserussell.com", "VIX": "cboe.com",
        // Technology
        "NVDA": "nvidia.com", "AAPL": "apple.com", "MSFT": "microsoft.com", "AVGO": "broadcom.com",
        "MU": "micron.com", "AMD": "amd.com", "INTC": "intel.com", "PLTR": "palantir.com",
        "CSCO": "cisco.com", "LRCX": "lamresearch.com", "AMAT": "appliedmaterials.com", "PANW": "paloaltonetworks.com",
        "SNDK": "sandisk.com", "CRWD": "crowdstrike.com", "ORCL": "oracle.com", "TXN": "ti.com",
        "KLAC": "kla.com", "MRVL": "marvell.com", "IBM": "ibm.com", "STX": "seagate.com",
        "ANET": "arista.com", "QCOM": "qualcomm.com", "APH": "amphenol.com", "CRM": "salesforce.com",
        "ADI": "analog.com", "DELL": "dell.com", "WDC": "westerndigital.com", "NOW": "servicenow.com",
        "GLW": "corning.com", "ACN": "accenture.com", "FTNT": "fortinet.com",
        // Communication Services
        "GOOGL": "abc.xyz", "META": "meta.com", "NFLX": "netflix.com", "VZ": "verizon.com",
        "DIS": "disney.com", "T": "att.com",
        // Consumer Discretionary
        "AMZN": "amazon.com", "TSLA": "tesla.com", "HD": "homedepot.com", "MCD": "mcdonalds.com",
        "TJX": "tjx.com", "BKNG": "bookingholdings.com", "NKE": "nike.com", "SBUX": "starbucks.com",
        // Consumer Staples
        "WMT": "walmart.com", "COST": "costco.com", "PG": "pg.com", "KO": "coca-colacompany.com",
        "PM": "pmi.com", "PEP": "pepsico.com", "MO": "altria.com", "NESN": "nestle.com",
        "UL": "unilever.com",
        // Healthcare
        "LLY": "lilly.com", "JNJ": "jnj.com", "ABBV": "abbvie.com", "MRK": "merck.com",
        "UNH": "unitedhealthgroup.com", "TMO": "thermofisher.com", "AMGN": "amgen.com", "GILD": "gilead.com",
        "ABT": "abbott.com", "PFE": "pfizer.com", "ISRG": "intuitive.com", "DHR": "danaher.com",
        "VRTX": "vrtx.com", "BMY": "bms.com", "MDT": "medtronic.com", "CVS": "cvshealth.com",
        // Financials
        "BRK-B": "berkshirehathaway.com", "JPM": "jpmorganchase.com", "V": "visa.com", "MA": "mastercard.com",
        "BAC": "bankofamerica.com", "GS": "goldmansachs.com", "WFC": "wellsfargo.com", "MS": "morganstanley.com",
        "C": "citigroup.com", "SCHW": "schwab.com", "AXP": "americanexpress.com", "BLK": "blackrock.com",
        "SPGI": "spglobal.com", "COF": "capitalone.com", "CB": "chubb.com", "PGR": "progressive.com",
        // Industrials
        "CAT": "caterpillar.com", "GE": "geaerospace.com", "RTX": "rtx.com", "GEV": "gevernova.com",
        "DE": "deere.com", "ETN": "eaton.com", "UNP": "up.com", "BA": "boeing.com",
        "UBER": "uber.com", "PH": "parker.com", "LMT": "lockheedmartin.com", "NOC": "northropgrumman.com",
        // Energy
        "XOM": "exxonmobil.com", "CVX": "chevron.com", "COP": "conocophillips.com", "MPC": "marathonpetroleum.com",
        "VLO": "valero.com",
        // Materials
        "LIN": "linde.com", "NEM": "newmont.com",
        // Utilities
        "NEE": "nexteraenergy.com",
        // Real Estate
        "WELL": "welltower.com", "PLD": "prologis.com",
        // Commodities: Metals — kept here for reference, but every
        // commodity symbol below is now intercepted by
        // CommodityIconCatalog.hasIcon(for:) in StockChip before this
        // domain map is ever consulted (see CommodityIcons.swift).
        "XPD": "cmegroup.com", "HG": "cmegroup.com",
        // Commodities: Energy — NYMEX (CME Group) lists WTI crude, natural
        // gas, RBOB gasoline and heating oil; Brent's home market is ICE.
        "CL": "cmegroup.com", "NG": "cmegroup.com", "RB": "cmegroup.com", "HO": "cmegroup.com",
        "BZ": "theice.com",
        // Commodities: Agriculture — CBOT (CME Group) lists the grains;
        // ICE Futures U.S. lists the softs (coffee/sugar/cotton/cocoa).
        "ZC": "cmegroup.com", "ZW": "cmegroup.com", "ZS": "cmegroup.com",
        "KC": "theice.com", "SB": "theice.com", "CT": "theice.com", "CC": "theice.com",
        // Commodities: Livestock — CME lists live cattle and lean hogs.
        "LE": "cmegroup.com", "HE": "cmegroup.com",
    ]
}

/// Small square/rounded logo badge for a ticker. Tries Clearbit's logo CDN
/// first; if there's no known domain or the fetch fails, shows a monogram
/// badge instead so the layout never breaks.
private struct CompanyLogoView: View {
    let symbol: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let domain = CompanyDomains.domain(for: symbol),
               let url = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
        )
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(StockSector.forSymbol(symbol).accentColor)
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }
}

// Precious-metal bars, industrial metals, energy, grains, softs, and
// livestock are all now handled by CommodityIconCatalog / CommodityIconView
// in CommodityIcons.swift — add that file to the target alongside this one.

// MARK: - Crypto logos
// Same domain → favicon → monogram-fallback pattern as CompanyDomains /
// CompanyLogoView, just pointed at each project's own official site instead
// of a company's, since Clearbit's CDN works off any real domain.

private enum CryptoDomains {
    static func domain(for symbol: String) -> String? {
        map[symbol.uppercased()]
    }

    private static let map: [String: String] = [
        "BTC": "bitcoin.org", "ETH": "ethereum.org", "SOL": "solana.com",
        "ADA": "cardano.org", "AVAX": "avax.network", "TRX": "tron.network",
        "TON": "ton.org", "DOT": "polkadot.network", "NEAR": "near.org",
        "APT": "aptoslabs.com", "SUI": "sui.io", "ATOM": "cosmos.network",
        "MATIC": "polygon.technology", "ARB": "arbitrum.io", "OP": "optimism.io",
        "UNI": "uniswap.org", "LINK": "chain.link", "AAVE": "aave.com", "MKR": "makerdao.com",
        "BNB": "binance.com",
        "USDT": "tether.to", "USDC": "circle.com", "DAI": "makerdao.com",
        "DOGE": "dogecoin.com", "SHIB": "shibatoken.com",
        // PEPE: no stable official domain — falls back to the monogram badge.
    ]
}

/// Same badge as CompanyLogoView (domain favicon, monogram fallback) but
/// keyed to CryptoDomains/CryptoSector instead of the stock-side lookups,
/// so the fallback tint matches this coin's crypto category, not a stock
/// sector it was never part of.
private struct CryptoLogoView: View {
    let symbol: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let domain = CryptoDomains.domain(for: symbol),
               let url = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
        )
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(CryptoSector.forSymbol(symbol).accentColor)
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }
}

/// Crypto's version of StockChipsSection/StockChip below — same layout and
/// follow-toggle behavior, keyed to the crypto catalog/logos instead.
private struct CryptoChipsSection: View {
    let sector: CryptoSector
    let items: [CryptoCatalogItem]
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(sector.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Ink.primary)
                Spacer()
            }

            FlowLayout(hSpacing: 12, vSpacing: 12) {
                ForEach(items) { item in
                    CryptoChip(item: item, viewModel: viewModel)
                }
            }
        }
    }
}

private struct CryptoChip: View {
    let item: CryptoCatalogItem
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var isAdding = false

    private var followedItem: MarketInstrumentItem? {
        viewModel.instruments(for: "crypto").first { $0.symbol.uppercased() == item.symbol.uppercased() }
    }
    private var isFollowing: Bool { followedItem?.enabled ?? false }

    var body: some View {
        HStack(spacing: 10) {
            CryptoLogoView(symbol: item.symbol, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.symbol.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Ink.primary)
                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Button {
                guard !isAdding else { return }
                if let followedItem {
                    viewModel.toggleInstrument(followedItem)
                } else {
                    isAdding = true
                    viewModel.addInstrument(
                        assetClass: "crypto",
                        symbol: item.symbol,
                        displayName: item.name,
                        threshold: 2.0
                    ) { _ in isAdding = false }
                }
            } label: {
                ZStack {
                    if isFollowing {
                        Circle().fill(Color(red: 0.20, green: 0.78, blue: 0.45))
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black)
                            .blendMode(.destinationOut)
                    } else {
                        Circle().strokeBorder(Color(red: 0.20, green: 0.78, blue: 0.45), lineWidth: 1.4)
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.45))
                    }
                }
                .compositingGroup()
                .frame(width: 16, height: 16)
                .opacity(isAdding ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isAdding)
        }
        .padding(10)
        .fixedSize()
        .glass(cornerRadius: 13)
    }
}

// MARK: - Flow layout
// Wraps chips left-to-right, top-to-bottom, like text — used to lay the
// per-sector stock chips out in rows that wrap instead of one-per-line.

private struct FlowLayout: Layout {
    var hSpacing: CGFloat = 10
    var vSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + vSpacing
                lineHeight = 0
            }
            x += size.width + hSpacing
            lineHeight = max(lineHeight, size.height)
        }
        y += lineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + vSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Root view

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @ObservedObject var ttsManager: TTSManager

    @State private var section: Section = .stocks

    var body: some View {
        ZStack {
            backdrop
            HStack(spacing: 0) {
                sidebar
                VStack(spacing: 0) {
                    if isAssetSection {
                        categoryTabs
                    }
                    ScrollView {
                        content
                            .padding(.horizontal, 40)
                            .padding(.top, 26)
                            .padding(.bottom, 50)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 820, minHeight: 520)
        .foregroundStyle(Ink.primary)
        .onAppear { viewModel.load() }
        .alert("Something went wrong", isPresented: $viewModel.showError, presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var isAssetSection: Bool {
        switch section {
        case .commodities, .stocks, .crypto, .poly, .news: return true
        default: return false
        }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        Sage.background.ignoresSafeArea()
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Sage.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Sage.cardBorder, lineWidth: 1))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Brass.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("CherubArrow").font(.system(size: 13.5, weight: .semibold))
                    Text("v1.4.0").font(.system(size: 10.5)).foregroundStyle(Ink.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 20)

            railItem(.stocks, label: "Home", icon: "house", isHomeAlias: true)

            Divider().padding(.vertical, 10).padding(.horizontal, 8).opacity(0.15)

            railItem(.voice, label: "Voice", icon: "waveform")
            railItem(.personalization, label: "Personalization", icon: "square.grid.2x2")
            railItem(.plan, label: "Plan", icon: "creditcard")

            Spacer()

            sidebarArt
                .padding(.bottom, 14)

            planSummaryCard
        }
        .padding(10)
        .frame(width: 208)
        .background(Sage.backgroundDeep)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(Color.white.opacity(0.06)), alignment: .trailing)
    }

    /// Decorative rocket-over-mountains glow art, echoing the reference
    /// mockup's sidebar illustration. Purely visual — no state or actions.
    private var sidebarArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Sage.accent.opacity(0.18), Color.clear],
                        startPoint: .bottom, endPoint: .top
                    )
                )
            VStack(spacing: 0) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Sage.accent.opacity(0.35))
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Sage.accent)
                    .offset(x: 14, y: -30)
            }
            .padding(.vertical, 14)
        }
        .frame(height: 90)
    }

    /// "Home" in the rail isn't its own page — it just resets you to the
    /// default dashboard state (Stocks tab selected), matching how a native
    /// sidebar's "Home" item usually behaves.
    private func railItem(_ target: Section, label: String, icon: String, isHomeAlias: Bool = false) -> some View {
        let isActive = isHomeAlias ? isAssetSection : (section == target)
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { section = target }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? Sage.accent : Ink.secondary)
                    .frame(width: 15)
                Text(label).font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(
                        LinearGradient(colors: [Sage.accent, Sage.accent.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                    ) : AnyShapeStyle(Color.clear))
            )
            .foregroundStyle(isActive ? Color.white : Ink.secondary)
        }
        .buttonStyle(.plain)
    }

    private var planSummaryCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("CURRENT PLAN").font(.system(size: 10, weight: .semibold)).foregroundStyle(Sage.accent)
            Text("News Premium").font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.primary)
            Text("Renews Oct 22, 2026").font(.system(size: 10.5)).foregroundStyle(Ink.secondary)
            Button {
                section = .plan
            } label: {
                Text("Manage plan")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Sage.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Sage.accent.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Sage.card)
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Sage.accent.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: Top category tabs

    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(AssetCategory.allCases, id: \.self) { cat in
                let isActive = currentCategory == cat
                Button {
                    withAnimation(.easeOut(duration: 0.12)) { section = sectionFor(cat) }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: cat.icon).font(.system(size: 13))
                        Text(cat.label).font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(isActive ? Color.white : Ink.secondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? AnyShapeStyle(
                                LinearGradient(colors: [Color(red: 0.145, green: 0.49, blue: 0.42), Color(red: 0.145, green: 0.49, blue: 0.42).opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            ) : AnyShapeStyle(Color.clear))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 11)
        .background(Sage.backgroundDeep)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.05)), alignment: .bottom)
    }

    private var currentCategory: AssetCategory? {
        switch section {
        case .commodities: return .commodities
        case .stocks: return .stocks
        case .crypto: return .crypto
        case .poly: return .poly
        case .news: return .news
        default: return nil
        }
    }
    private func sectionFor(_ cat: AssetCategory) -> Section {
        switch cat {
        case .commodities: return .commodities
        case .stocks: return .stocks
        case .crypto: return .crypto
        case .poly: return .poly
        case .news: return .news
        }
    }

    // MARK: Content router

    @ViewBuilder
    private var content: some View {
        switch section {
        case .commodities: AssetCategoryPane(category: .commodities, viewModel: viewModel)
        case .stocks: AssetCategoryPane(category: .stocks, viewModel: viewModel)
        case .crypto: AssetCategoryPane(category: .crypto, viewModel: viewModel)
        case .poly: AssetCategoryPane(category: .poly, viewModel: viewModel)
        case .news: NewsPane(viewModel: viewModel)
        case .voice: VoicePane(ttsManager: ttsManager)
        case .personalization: PersonalizationPane()
        case .plan: PlanPane()
        }
    }
}

// MARK: - Asset category pane (Stocks / Crypto / Polymarket)
// Monitoring app, not a live dashboard: these are follow-lists only. Nothing
// renders live in-app — a followed item just becomes eligible to be read
// aloud on a double-click, per Voice tab settings.
//
// News sources used to be duplicated in each of these three panes; they now
// live solely in the standalone News section (see NewsPane below), which
// covers all three categories plus general coverage in one place.
//
// Stocks only: no page title, no "Live updates" section, and no "All
// stocks" header — just a bare sector label ("Technology", etc.) followed by
// a wrapping row of compact logo+ticker+name chips for every stock in that
// sector, matching the tryBloom.xyz reference layout. Crypto and Polymarket
// keep the original profile-card layout untouched.

private struct AssetCategoryPane: View {
    let category: AssetCategory
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var showAddInstrument = false

    private var instruments: [MarketInstrumentItem] {
        viewModel.instruments(for: category.instrumentAssetClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if category != .stocks && category != .commodities && category != .crypto {
                sectionHeader("LIVE UPDATES", count: instruments.count) { showAddInstrument = true }
                if instruments.isEmpty {
                    emptyState(text: "Nothing followed yet in \(category.label) — use Follow to add one.")
                } else if category == .poly {
                    VStack(spacing: 9) {
                        ForEach(instruments) { item in
                            EventRow(item: item, viewModel: viewModel)
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(instruments) { item in
                            ProfileCard(
                                initials: String(item.symbol.prefix(4)).uppercased(),
                                name: item.displayName,
                                handle: "\(item.symbol.uppercased()) · \(category == .crypto ? "CoinGecko" : "NASDAQ")",
                                isFollowing: item.enabled,
                                avatarShape: .circle
                            ) { viewModel.toggleInstrument(item) }
                        }
                    }
                }
            }

            if category == .stocks {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(StockCatalog.bySector, id: \.sector) { group in
                        StockChipsSection(sector: group.sector, items: group.items, viewModel: viewModel)
                    }
                }
                .padding(.bottom, 12)
            } else if category == .commodities {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(StockCatalog.commodities, id: \.sector) { group in
                        StockChipsSection(sector: group.sector, items: group.items, viewModel: viewModel)
                    }
                }
                .padding(.bottom, 12)
            } else if category == .crypto {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(CryptoCatalog.bySector, id: \.sector) { group in
                        CryptoChipsSection(sector: group.sector, items: group.items, viewModel: viewModel)
                    }
                }
                .padding(.bottom, 12)
            } else if category == .poly {
                // No static catalog here — Polymarket's active events churn
                // daily, so this is fetched live instead of hand-maintained
                // like StockCatalog/CryptoCatalog. See PolymarketAPI.swift.
                TrendingPolymarketSection(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showAddInstrument) {
            if category == .poly {
                PolymarketBrowseSheet(viewModel: viewModel)
            } else {
                AddInstrumentSheet(category: category, viewModel: viewModel)
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int, addAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Ink.secondary)
                .tracking(0.5)
            Text("\(count) followed")
                .font(.system(size: 10))
                .foregroundStyle(Ink.tertiary)
            Spacer()
            Button(action: addAction) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                    Text("Follow")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Sage.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Ink.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.white.opacity(0.14))
            )
    }
}

/// One sector's worth of stock chips: a bold sector label, then every stock
/// in that sector as a wrapping row of `StockChip`s — no card background,
/// sitting directly on the page, matching the reference design.
private struct StockChipsSection: View {
    let sector: StockSector
    let items: [StockCatalogItem]
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(sector.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Ink.primary)
                Spacer()
            }

            FlowLayout(hSpacing: 12, vSpacing: 12) {
                ForEach(items) { item in
                    StockChip(item: item, viewModel: viewModel)
                }
            }
        }
    }
}

/// Logo + ticker + company name + a small circular follow/following
/// affordance (plus = not following, checkmark = following). Tapping it
/// follows/unfollows through the existing view-model calls. Sized to its
/// own content (not a fixed grid cell) so the name is never clipped or
/// wrapped letter-by-letter.
private struct StockChip: View {
    let item: StockCatalogItem
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var isAdding = false

    private var followedItem: MarketInstrumentItem? {
        viewModel.instruments(for: "stock").first { $0.symbol.uppercased() == item.symbol.uppercased() }
    }
    private var isFollowing: Bool { followedItem?.enabled ?? false }

    var body: some View {
        HStack(spacing: 10) {
            if CommodityIconCatalog.hasIcon(for: item.symbol) {
                // Real commodity glyph (oil drop, flame, ingot, corn, etc.)
                // drawn natively — see CommodityIcons.swift. Replaces the old
                // favicon-CDN lookup, which just returned CME/ICE's own
                // corporate mark (a globe, or ICE's boxed logotype) for every
                // futures ticker regardless of what it actually was.
                CommodityIconView(symbol: item.symbol, size: 34)
            } else {
                CompanyLogoView(symbol: item.symbol, size: 34)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.symbol.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Ink.primary)
                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Button {
                guard !isAdding else { return }
                if let followedItem {
                    viewModel.toggleInstrument(followedItem)
                } else {
                    isAdding = true
                    viewModel.addInstrument(
                        assetClass: "stock",
                        symbol: item.symbol,
                        displayName: item.name,
                        threshold: 2.0
                    ) { _ in isAdding = false }
                }
            } label: {
                ZStack {
                    if isFollowing {
                        // Filled solid, with the checkmark knocked OUT of the
                        // fill (blendMode .destinationOut inside a
                        // compositingGroup erases those pixels) so the card
                        // background shows through the check shape, instead
                        // of drawing a check on top of the green.
                        Circle().fill(Color(red: 0.20, green: 0.78, blue: 0.45))
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black)
                            .blendMode(.destinationOut)
                    } else {
                        Circle().strokeBorder(Color(red: 0.20, green: 0.78, blue: 0.45), lineWidth: 1.4)
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.45))
                    }
                }
                .compositingGroup()
                .frame(width: 16, height: 16)
                .opacity(isAdding ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isAdding)
        }
        .padding(10)
        .fixedSize()
        .glass(cornerRadius: 13)
    }
}

private enum AvatarShape { case circle, roundedSquare }

/// A flat white rectangular card for a single followable asset or news
/// source — logo badge, name, ticker/subtitle, and an X/Twitter-style Follow
/// button (filled black pill when not following, outlined "Following" pill
/// with a hover-to-unfollow affordance when already following).
/// Still used as-is for Crypto/Polymarket instruments and for all news
/// sources.
private struct ProfileCard: View {
    let initials: String
    let name: String
    let handle: String
    let isFollowing: Bool
    let avatarShape: AvatarShape
    let toggle: () -> Void

    @State private var isHoveringFollowing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Group {
                        if avatarShape == .circle {
                            Circle().fill(Sage.background)
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Sage.background)
                        }
                    }
                    Text(initials).font(.system(size: 12, weight: .bold)).foregroundStyle(Sage.forest)
                }
                .frame(width: 40, height: 40)

                Spacer()

                Button(action: toggle) {
                    Group {
                        if isFollowing {
                            Text(isHoveringFollowing ? "Unfollow" : "Following")
                                .foregroundStyle(isHoveringFollowing ? Color.red : Ink.primary)
                        } else {
                            Text("Follow").foregroundStyle(Color.white)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(
                        Group {
                            if isFollowing {
                                Capsule()
                                    .strokeBorder(isHoveringFollowing ? Color.red.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1)
                                    .background(Capsule().fill(Sage.card))
                            } else {
                                Capsule().fill(Ink.primary)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveringFollowing = isFollowing && $0 }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Ink.primary).lineLimit(1)
                Text(handle).font(.system(size: 11.5)).foregroundStyle(Ink.tertiary).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(cornerRadius: 16)
    }
}

private struct EventRow: View {
    let item: MarketInstrumentItem
    @ObservedObject var viewModel: PreferencesViewModel

    @State private var isHoveringFollowing = false
    // Live Yes-probability, refreshed from Polymarket's public Gamma API on
    // appear (see PolymarketAPI.swift). This is a display-only read — it
    // doesn't touch whatever backend job eventually does the threshold-cross
    // alert for the read-aloud feature.
    @State private var liveEvent: PolymarketEvent?
    @State private var hasLoaded = false
    @State private var isToggling = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Sage.background)
                if let event = liveEvent, event.isExpired {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Ink.tertiary)
                } else if let p = liveEvent?.yesProbability {
                    Text("\(Int((p * 100).rounded()))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(p >= 0.5
                            ? Color(red: 0.30, green: 0.78, blue: 0.45)
                            : Color(red: 0.90, green: 0.40, blue: 0.40))
                } else if hasLoaded {
                    // Loaded, but no usable price (event pulled, no markets yet, etc.)
                    Image(systemName: "questionmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Ink.tertiary)
                } else {
                    ProgressView().scaleEffect(0.5)
                }
            }
            .frame(width: 36, height: 36)
            .task {
                liveEvent = try? await PolymarketAPI.fetchEvent(slug: item.symbol)
                hasLoaded = true
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.primary)
                if let event = liveEvent, event.isExpired {
                    Text("Market closed").font(.system(size: 11)).foregroundStyle(Ink.tertiary)
                } else {
                    Text(item.symbol).font(.system(size: 11)).foregroundStyle(Ink.tertiary)
                }
            }
            Spacer(minLength: 4)

            Button {
                guard !isToggling else { return }
                isToggling = true
                viewModel.toggleInstrument(item)
                // toggleInstrument doesn't report completion back to this
                // view, so this just clears the brief tap-feedback state
                // rather than waiting on a real callback.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isToggling = false }
            } label: {
                Group {
                    if isToggling {
                        ProgressView().scaleEffect(0.6)
                    } else if item.enabled {
                        Text(isHoveringFollowing ? "Unfollow" : "Following")
                            .foregroundStyle(isHoveringFollowing ? Color.red : Ink.primary)
                    } else {
                        Text("Follow").foregroundStyle(Color.white)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .frame(minWidth: 64)
                .background(
                    Group {
                        if item.enabled {
                            Capsule()
                                .strokeBorder(isHoveringFollowing ? Color.red.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 1)
                                .background(Capsule().fill(Sage.card))
                        } else {
                            Capsule().fill(Sage.accent)
                        }
                    }
                )
                .opacity(isToggling ? 0.6 : 1.0)
                .scaleEffect(isToggling ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isToggling)
            }
            .buttonStyle(.plain)
            .onHover { isHoveringFollowing = item.enabled && $0 }
        }
        .padding(14)
        .glass(cornerRadius: 16)
    }
}

// MARK: - Add sheets

private struct AddInstrumentSheet: View {
    let category: AssetCategory
    @ObservedObject var viewModel: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var symbol = ""
    @State private var displayName = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Follow \(category == .poly ? "a market" : String(category.label.dropLast()))")
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(symbolLabel).font(.system(size: 11)).foregroundStyle(Ink.secondary)
                TextField(symbolPlaceholder, text: $symbol).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Display name").font(.system(size: 11)).foregroundStyle(Ink.secondary)
                TextField("Apple Inc.", text: $displayName).textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isSubmitting ? "Adding…" : "Follow") {
                    isSubmitting = true
                    viewModel.addInstrument(assetClass: category.instrumentAssetClass, symbol: symbol, displayName: displayName, threshold: 2.0) { success in
                        isSubmitting = false
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(symbol.isEmpty || displayName.isEmpty || isSubmitting)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var symbolLabel: String {
        switch category {
        case .commodities: return "Ticker symbol" // unreachable: this sheet is never shown for .commodities
        case .stocks: return "Ticker symbol"
        case .crypto: return "CoinGecko id"
        case .poly: return "Polymarket slug"
        case .news: return "Ticker symbol" // unreachable: this sheet is never shown for .news
        }
    }
    private var symbolPlaceholder: String {
        switch category {
        case .commodities: return "XAU" // unreachable: this sheet is never shown for .commodities
        case .stocks: return "AAPL"
        case .crypto: return "bitcoin"
        case .poly: return "will-fed-cut-rates-q4-2026"
        case .news: return "AAPL" // unreachable: this sheet is never shown for .news
        }
    }
}

// MARK: - News source logos
// News sources are user-added (name + RSS URL), so there's no ticker to key
// off of like the stock catalog — just a hand-maintained name -> domain map
// for the common outlets people actually follow. Anything not in the map
// falls back to a monogram badge, same pattern as CompanyLogoView.

private enum NewsSourceDomains {
    static func domain(for name: String) -> String? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return map[key]
    }

    private static let map: [String: String] = [
        // General / broad markets
        "marketwatch": "marketwatch.com",
        "bloomberg": "bloomberg.com",
        "reuters": "reuters.com",
        "cnbc": "cnbc.com",
        "the wall street journal": "wsj.com",
        "wsj": "wsj.com",
        "financial times": "ft.com",
        "ft": "ft.com",
        "yahoo finance": "finance.yahoo.com",
        "barron's": "barrons.com",
        "barrons": "barrons.com",
        "the economist": "economist.com",
        "axios": "axios.com",
        "associated press": "apnews.com",
        "ap news": "apnews.com",
        "business insider": "businessinsider.com",
        "forbes": "forbes.com",
        "fortune": "fortune.com",
        "seeking alpha": "seekingalpha.com",
        "investing.com": "investing.com",
        "benzinga": "benzinga.com",
        "morningstar": "morningstar.com",
        "the motley fool": "fool.com",
        "motley fool": "fool.com",
        // Crypto
        "coindesk": "coindesk.com",
        "cointelegraph": "cointelegraph.com",
        "the block": "theblock.co",
        "decrypt": "decrypt.co",
        "coingecko": "coingecko.com",
        "coinmarketcap": "coinmarketcap.com",
        "bitcoin magazine": "bitcoinmagazine.com",
        // Polymarket / prediction markets
        "polymarket": "polymarket.com",
        "polymarket blog": "polymarket.com",
        "kalshi": "kalshi.com",
        "the dispatch": "thedispatch.com",
        "fivethirtyeight": "abcnews.go.com",
        "election betting odds": "electionbettingodds.com",
    ]
}

/// Small logo badge for a news source, keyed by its display name via
/// `NewsSourceDomains`. Falls back to a monogram badge, identical treatment
/// to `CompanyLogoView` used for stock chips.
private struct NewsSourceLogoView: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let domain = NewsSourceDomains.domain(for: name),
               let url = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
        )
    }

    private var fallback: some View {
        ZStack {
            Rectangle().fill(Sage.background)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(Sage.forest)
        }
    }
}

/// Logo + name + a small circular follow/following affordance — the news
/// equivalent of `StockChip`, used for every source row in the News tab.
private struct NewsSourceChip: View {
    let item: NewsSourceItem
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        HStack(spacing: 6) {
            NewsSourceLogoView(name: item.name, size: 20)

            Text(item.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Ink.primary)
                .lineLimit(1)

            Button {
                viewModel.toggleNewsSource(item)
            } label: {
                ZStack {
                    Circle().fill(Sage.accent)
                    Image(systemName: item.enabled ? "checkmark" : "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 17, height: 17)
            }
            .buttonStyle(.plain)
        }
        .fixedSize()
    }
}

/// Per-category identity for the News tab — a distinct tint and icon badge
/// per source category (not the flat Sage.accent used everywhere else),
/// so Stocks / Crypto / Polymarket read as three differently-flavored rooms
/// on the same page rather than three copies of the same header style.
private struct NewsCategoryStyle {
    let tint: Color
    let tintDeep: Color

    static func style(for category: AssetCategory) -> NewsCategoryStyle {
        switch category {
        case .commodities:
            // unreachable: NewsPane only ever passes .stocks/.crypto/.poly
            return NewsCategoryStyle(
                tint: Color(red: 0.72, green: 0.58, blue: 0.10),
                tintDeep: Color(red: 0.95, green: 0.90, blue: 0.70)
            )
        case .stocks:
            return NewsCategoryStyle(
                tint: Color(red: 0.20, green: 0.45, blue: 0.80),
                tintDeep: Color(red: 0.82, green: 0.90, blue: 0.99)
            )
        case .crypto:
            return NewsCategoryStyle(
                tint: Color(red: 0.75, green: 0.55, blue: 0.05),
                tintDeep: Color(red: 1.00, green: 0.93, blue: 0.73)
            )
        case .poly:
            return NewsCategoryStyle(
                tint: Color(red: 0.55, green: 0.35, blue: 0.80),
                tintDeep: Color(red: 0.92, green: 0.84, blue: 0.99)
            )
        case .news:
            return NewsCategoryStyle(tint: Sage.accent, tintDeep: Sage.background)
        }
    }
}

/// One category's worth of news-source chips, styled as its own card with a
/// tinted icon badge and a rule under the header — three visually distinct
/// rooms on the page instead of three plain text headings. No "Add source"
/// affordance: sources aren't user-manageable here.
private struct NewsCategorySection: View {
    let category: AssetCategory
    @ObservedObject var viewModel: PreferencesViewModel

    private var sources: [NewsSourceItem] {
        viewModel.newsSources(for: category.newsCategory)
    }
    private var style: NewsCategoryStyle { .style(for: category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(style.tintDeep)
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(style.tint)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.label)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Ink.primary)
                    Text("\(sources.filter { $0.enabled }.count) of \(sources.count) sources followed")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
            }

            Rectangle()
                .fill(style.tint.opacity(0.18))
                .frame(height: 1)

            if sources.isEmpty {
                Text("No \(category.label.lowercased()) sources yet.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Ink.secondary)
                    .padding(.top, 2)
            } else {
                FlowLayout(hSpacing: 22, vSpacing: 14) {
                    ForEach(sources) { item in
                        NewsSourceChip(item: item, viewModel: viewModel)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Sage.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style.tint.opacity(0.16), lineWidth: 1)
        )
    }
}

// MARK: - News pane
// A 4th tab in the same row as Stocks / Crypto / Polymarket (not a separate
// sidebar destination). Inside it, those three categories reappear as three
// distinctly-tinted cards — each its own visual "room" rather than a plain
// heading — so every followed news source across all three is visible with
// its logo in one place. Sources aren't user-addable here, only followable.

private struct NewsPane: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            NewsCategorySection(category: .stocks, viewModel: viewModel)
            NewsCategorySection(category: .crypto, viewModel: viewModel)
            NewsCategorySection(category: .poly, viewModel: viewModel)
        }
        .padding(.bottom, 12)
    }
}

private struct AddNewsSourceSheet: View {
    let category: AssetCategory
    @ObservedObject var viewModel: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var rssUrl = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a \(category.label) news source").font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.system(size: 11)).foregroundStyle(Ink.secondary)
                TextField("MarketWatch", text: $name).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("RSS feed URL").font(.system(size: 11)).foregroundStyle(Ink.secondary)
                TextField("https://…/rss.xml", text: $rssUrl).textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isSubmitting ? "Adding…" : "Add") {
                    isSubmitting = true
                    viewModel.addNewsSource(name: name, rssUrl: rssUrl, category: category.newsCategory) { success in
                        isSubmitting = false
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || rssUrl.isEmpty || isSubmitting)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

// MARK: - Voice pane

private struct VoicePane: View {
    @ObservedObject var ttsManager: TTSManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Voice").font(.system(size: 19, weight: .semibold))
            Text("Tune how CherubArrow sounds — speed, pacing, and which engine speaks.")
                .font(.system(size: 12.5)).foregroundStyle(Ink.secondary).padding(.top, 4)
                .frame(maxWidth: 480, alignment: .leading)

            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Sage.background)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Sage.accent.opacity(0.3), lineWidth: 1))
                    Image(systemName: "waveform").font(.system(size: 22)).foregroundStyle(Sage.accent)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ttsManager.isPiperAvailable ? "Lessac — English (US)" : "System voice (fallback)")
                        .font(.system(size: 14, weight: .semibold))
                    Text(ttsManager.isPiperAvailable
                         ? "Piper offline voice · medium quality · running locally, no network required"
                         : "Piper isn't installed — using Apple's built-in voice until it is.")
                        .font(.system(size: 12)).foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button {
                    ttsManager.speak("This is what I sound like right now.")
                } label: {
                    HStack(spacing: 6) { Image(systemName: "play.fill"); Text("Preview") }
                        .font(.system(size: 12.5, weight: .semibold))
                        .padding(.horizontal, 13).padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .glass(cornerRadius: 9)
            }
            .padding(18)
            .glass(cornerRadius: 16)
            .padding(.top, 22)
            .padding(.bottom, 4)

            sectionLabel("SPEECH TUNING")
            VStack(spacing: 12) {
                sliderRow(
                    title: "Speaking speed",
                    hint: "Lower length scale = faster speech.",
                    valueLabel: String(format: "%.2fx (length scale %.2f)", 1.6 - ttsManager.lengthScale, ttsManager.lengthScale),
                    value: Binding(get: { ttsManager.lengthScale }, set: { ttsManager.lengthScale = $0 }),
                    range: 0.85...1.6,
                    leftLabel: "Faster", rightLabel: "Slower"
                )
                sliderRow(
                    title: "Pause between sentences",
                    hint: "More breathing room for longer updates.",
                    valueLabel: String(format: "%.1fs", ttsManager.sentenceSilence),
                    value: Binding(get: { ttsManager.sentenceSilence }, set: { ttsManager.sentenceSilence = $0 }),
                    range: 0.0...1.2,
                    leftLabel: "0.0s", rightLabel: "1.2s"
                )
            }

            sectionLabel("WHAT GETS SPOKEN ON DOUBLE-CLICK")
            VStack(spacing: 0) {
                togglePlaceholderRow("Followed stock updates")
                togglePlaceholderRow("Followed crypto updates")
                togglePlaceholderRow("Followed Polymarket updates")
                togglePlaceholderRow("Followed news headlines")
                togglePlaceholderRow("Occasional affirmation", hint: "5% chance on an isolated click, rate-limited to once per 90s.")
            }
            .padding(.vertical, 6)
            .glass(cornerRadius: 16)

            Text("These toggles aren't persisted yet — only speaking speed and sentence pause save for real right now.")
                .font(.system(size: 11)).foregroundStyle(Ink.tertiary).padding(.top, 10)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.secondary).tracking(0.5)
            .padding(.top, 24).padding(.bottom, 10)
    }

    private func sliderRow(title: String, hint: String, valueLabel: String, value: Binding<Double>, range: ClosedRange<Double>, leftLabel: String, rightLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(hint).font(.system(size: 11)).foregroundStyle(Ink.tertiary)
                }
                Spacer()
                Text(valueLabel).font(.system(size: 12, weight: .semibold)).foregroundStyle(Brass.color).monospacedDigit()
            }
            Slider(value: value, in: range).tint(Brass.color)
            HStack {
                Text(leftLabel).font(.system(size: 10)).foregroundStyle(Ink.tertiary)
                Spacer()
                Text(rightLabel).font(.system(size: 10)).foregroundStyle(Ink.tertiary)
            }
        }
        .padding(17)
        .glass(cornerRadius: 16)
    }

    private func togglePlaceholderRow(_ title: String, hint: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let hint { Text(hint).font(.system(size: 11)).foregroundStyle(Ink.tertiary) }
            }
            Spacer()
            Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch).disabled(true)
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
    }
}

// MARK: - Personalization pane (mockup only — no backend yet)

private struct PersonalizationPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Personalization").font(.system(size: 19, weight: .semibold))
            Text("Shape which content types and effects show up during clicks.")
                .font(.system(size: 12.5)).foregroundStyle(Ink.secondary).padding(.top, 4)

            Text("CONTENT TYPES").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.secondary).tracking(0.5)
                .padding(.top, 24).padding(.bottom, 10)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                toggleCard("sparkles", "Affirmations", "Short encouraging lines, spoken occasionally.")
                toggleCard("clock", "Quick facts", "Bite-size trivia read aloud on a double-click.")
                toggleCard("doc.text", "News headlines", "Reads recent headlines from your followed sources.")
                toggleCard("chart.line.uptrend.xyaxis", "Market updates", "Stocks, crypto, and Polymarket you follow.")
            }

            Text("VISUAL EFFECTS").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.secondary).tracking(0.5)
                .padding(.top, 24).padding(.bottom, 10)
            VStack(spacing: 0) {
                effectRow("Sparkle stars")
                effectRow("Candy burst")
                effectRow("Confetti")
            }
            .padding(.vertical, 6)
            .glass(cornerRadius: 16)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(Ink.tertiary)
                Text("Mockup only — these toggles don't persist yet. Needs a `personalization` table and matching edge-function actions, same pattern as Stocks/Crypto/Polymarket follows.")
                    .font(.system(size: 11.5)).foregroundStyle(Ink.secondary)
            }
            .padding(14)
            .glass(cornerRadius: 12)
            .padding(.top, 20)
        }
    }

    private func toggleCard(_ icon: String, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Sage.background)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Sage.cardBorder, lineWidth: 1))
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(Sage.forest)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch).disabled(true)
                }
                Text(sub).font(.system(size: 11)).foregroundStyle(Ink.tertiary)
            }
        }
        .padding(15)
        .glass(cornerRadius: 15)
    }

    private func effectRow(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch).disabled(true)
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
    }
}

// MARK: - Plan pane (mockup only — real licenses/subscriptions tables exist but aren't read here yet)

private struct PlanPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Plan & billing").font(.system(size: 19, weight: .semibold))
            Text("CherubArrow is a one-time purchase. News Premium is an optional add-on subscription.")
                .font(.system(size: 12.5)).foregroundStyle(Ink.secondary).padding(.top, 4)

            HStack(spacing: 14) {
                planCard(name: "CherubArrow", price: "$14", period: "one-time", featured: false, features: [
                    "Click effects & sound", "Offline Piper voice (Lessac)", "Stocks, crypto & Polymarket follows", "Up to 3 devices"
                ], cta: "Owned · Licensed")
                planCard(name: "News Premium", price: "$3", period: "/month", featured: true, features: [
                    "Everything in CherubArrow", "Unlimited followed news sources", "Deep-cut fact tier & LibriTTS voices"
                ], cta: "Active · renews Oct 22")
            }
            .padding(.top, 20)

            Text("LICENSE").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.secondary).tracking(0.5)
                .padding(.top, 24).padding(.bottom, 10)
            VStack(spacing: 0) {
                licenseRow(title: "License key", sub: "CHRB-7F2K-9QXA-01MZ", action: "Copy")
                Divider().opacity(0.1)
                licenseRow(title: "Activated devices", sub: "2 of 3 used", action: "Manage")
            }
            .glass(cornerRadius: 15)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(Ink.tertiary)
                Text("Mockup only — plan/billing shown here is illustrative. The backend already has `licenses`, `subscriptions`, and `device_activations` tables; this pane isn't reading from them yet.")
                    .font(.system(size: 11.5)).foregroundStyle(Ink.secondary)
            }
            .padding(14)
            .glass(cornerRadius: 12)
            .padding(.top, 20)
        }
    }

    private func planCard(name: String, price: String, period: String, featured: Bool, features: [String], cta: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name).font(.system(size: 14, weight: .semibold))
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(price).font(.system(size: 27, weight: .bold))
                Text(period).font(.system(size: 12)).foregroundStyle(Ink.secondary)
            }
            .padding(.top, 10)

            VStack(spacing: 0) {
                ForEach(features, id: \.self) { f in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.green)
                        Text(f).font(.system(size: 12)).foregroundStyle(Ink.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    if f != features.last { Divider().opacity(0.1) }
                }
            }
            .padding(.top, 16)

            Text(cta)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .glass(cornerRadius: 10)
                .padding(.top, 16)
        }
        .padding(21)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(featured ? AnyShapeStyle(Sage.background) : AnyShapeStyle(Sage.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(featured ? Sage.accent.opacity(0.4) : Sage.cardBorder, lineWidth: 1))
        )
    }

    private func licenseRow(title: String, sub: String, action: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(sub).font(.system(size: 11.5)).foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Button(action) {}
                .buttonStyle(.bordered)
                .font(.system(size: 11.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}
