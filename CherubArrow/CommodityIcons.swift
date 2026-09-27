import SwiftUI

// MARK: - Commodity glyphs (flat, single-tone, Binance-style badges)
//
// Replaces the favicon-CDN lookup (CompanyDomains → CompanyLogoView) for
// every commodity ticker. That path was fetching CME/ICE's own tiny
// corporate mark — which is why WTI, natural gas, wheat, coffee, etc. all
// rendered as the same generic globe, and the ICE-listed softs (BZ, KC, SB,
// CT, CC) rendered as ICE's boxed logotype instead of anything about the
// actual commodity.
//
// Every icon here is drawn natively in SwiftUI (no network fetch, so it can
// never fall back to a globe or someone else's exchange logo): a solid
// colored rounded-square badge with one minimal white/tinted glyph, same
// footprint as CompanyLogoView so chip rows keep lining up identically.

private enum Glyph {
    case sf(String)                 // a real SF Symbol that already reads correctly at this size
    case ingot                      // gold/silver/platinum/palladium bar
    case corn, wheat, soybean, cotton, cocoa
    case cattle, hog
}

private struct IconStyle {
    let glyph: Glyph
    let tint: Color
    let background: Color
}

enum CommodityIconCatalog {
    /// Call this from a chip's icon-selection `if` to decide whether to use
    /// CommodityIconView at all — everything not in this catalog (regular
    /// stocks) should keep going through CompanyLogoView as before.
    static func hasIcon(for symbol: String) -> Bool { map[symbol.uppercased()] != nil }

    fileprivate static func lookup(_ symbol: String) -> IconStyle? { map[symbol.uppercased()] }

    private static let map: [String: IconStyle] = [
        // Energy
        "CL": IconStyle(glyph: .sf("drop.fill"),      tint: .white, background: Color(red: 0.15, green: 0.15, blue: 0.16)),
        "BZ": IconStyle(glyph: .sf("drop.fill"),      tint: .white, background: Color(red: 0.09, green: 0.22, blue: 0.42)),
        "NG": IconStyle(glyph: .sf("flame.fill"),     tint: .white, background: Color(red: 0.03, green: 0.44, blue: 0.64)),
        "RB": IconStyle(glyph: .sf("fuelpump.fill"),  tint: .white, background: Color(red: 0.74, green: 0.16, blue: 0.16)),
        "HO": IconStyle(glyph: .sf("flame.fill"),     tint: .white, background: Color(red: 0.80, green: 0.36, blue: 0.09)),

        // Metals
        "XAU": IconStyle(glyph: .ingot, tint: Color(red: 0.90, green: 0.73, blue: 0.24), background: Color(red: 0.09, green: 0.09, blue: 0.11)),
        "XAG": IconStyle(glyph: .ingot, tint: Color(red: 0.80, green: 0.81, blue: 0.83), background: Color(red: 0.09, green: 0.09, blue: 0.11)),
        "XPT": IconStyle(glyph: .ingot, tint: Color(red: 0.74, green: 0.80, blue: 0.84), background: Color(red: 0.09, green: 0.09, blue: 0.11)),
        "XPD": IconStyle(glyph: .ingot, tint: Color(red: 0.85, green: 0.83, blue: 0.78), background: Color(red: 0.09, green: 0.09, blue: 0.11)),
        "HG":  IconStyle(glyph: .sf("bolt.fill"), tint: Color(red: 0.85, green: 0.55, blue: 0.30), background: Color(red: 0.09, green: 0.09, blue: 0.11)),

        // Agriculture
        "ZC": IconStyle(glyph: .corn,    tint: Color(red: 0.96, green: 0.78, blue: 0.20), background: Color(red: 0.15, green: 0.13, blue: 0.09)),
        "ZW": IconStyle(glyph: .wheat,   tint: Color(red: 0.90, green: 0.74, blue: 0.34), background: Color(red: 0.15, green: 0.13, blue: 0.09)),
        "ZS": IconStyle(glyph: .soybean, tint: Color(red: 0.60, green: 0.74, blue: 0.44), background: Color(red: 0.11, green: 0.14, blue: 0.10)),
        "KC": IconStyle(glyph: .sf("cup.and.saucer.fill"), tint: .white, background: Color(red: 0.32, green: 0.20, blue: 0.13)),
        "SB": IconStyle(glyph: .sf("cube.fill"), tint: .white, background: Color(red: 0.18, green: 0.44, blue: 0.28)),
        "CT": IconStyle(glyph: .cotton,  tint: .white, background: Color(red: 0.20, green: 0.34, blue: 0.18)),
        "CC": IconStyle(glyph: .cocoa,   tint: Color(red: 0.88, green: 0.76, blue: 0.47), background: Color(red: 0.30, green: 0.17, blue: 0.10)),

        // Livestock
        "LE": IconStyle(glyph: .cattle, tint: .white, background: Color(red: 0.42, green: 0.28, blue: 0.16)),
        "HE": IconStyle(glyph: .hog,    tint: .white, background: Color(red: 0.74, green: 0.47, blue: 0.53)),
    ]
}

/// Same badge footprint as CompanyLogoView / PreciousMetalBarView, so it
/// drops straight into any chip row. Pass this the raw ticker (e.g. "CL",
/// "XAU", "ZC") — unknown symbols fall back to a plain monogram, same as
/// CompanyLogoView already does, so layout never breaks.
struct CommodityIconView: View {
    let symbol: String
    var size: CGFloat = 20

    private var style: IconStyle? { CommodityIconCatalog.lookup(symbol) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(style?.background ?? Color(red: 0.09, green: 0.09, blue: 0.11))
            glyphView
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
        )
    }

    @ViewBuilder
    private var glyphView: some View {
        if let style {
            switch style.glyph {
            case .sf(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(style.tint)

            case .ingot:
                IngotShape()
                    .fill(style.tint)
                    .frame(width: size * 0.6, height: size * 0.38)

            case .corn:
                ZStack {
                    Capsule().fill(style.tint)
                    VStack(spacing: size * 0.055) {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: size * 0.05) {
                                Circle().fill(Color.black.opacity(0.22)).frame(width: size * 0.055, height: size * 0.055)
                                Circle().fill(Color.black.opacity(0.22)).frame(width: size * 0.055, height: size * 0.055)
                            }
                        }
                    }
                }
                .frame(width: size * 0.34, height: size * 0.6)

            case .wheat:
                WheatShape()
                    .stroke(style.tint, lineWidth: size * 0.07)
                    .frame(width: size * 0.46, height: size * 0.62)

            case .soybean:
                ZStack {
                    Capsule().fill(style.tint)
                    HStack(spacing: size * 0.045) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().fill(Color.white.opacity(0.85)).frame(width: size * 0.14, height: size * 0.14)
                        }
                    }
                }
                .frame(width: size * 0.58, height: size * 0.32)

            case .cotton:
                ZStack {
                    Circle().fill(style.tint).frame(width: size * 0.26, height: size * 0.26).offset(x: -size * 0.15, y: -size * 0.04)
                    Circle().fill(style.tint).frame(width: size * 0.3, height: size * 0.3)
                    Circle().fill(style.tint).frame(width: size * 0.26, height: size * 0.26).offset(x: size * 0.15, y: -size * 0.04)
                }

            case .cocoa:
                ZStack {
                    Capsule().fill(style.tint)
                    Rectangle().fill(Color.black.opacity(0.18)).frame(width: size * 0.03)
                }
                .frame(width: size * 0.32, height: size * 0.58)

            case .cattle:
                ZStack {
                    Circle().fill(style.tint).frame(width: size * 0.5, height: size * 0.5)
                    HStack(spacing: size * 0.32) {
                        Capsule().fill(style.tint).frame(width: size * 0.14, height: size * 0.22).rotationEffect(.degrees(-20))
                        Capsule().fill(style.tint).frame(width: size * 0.14, height: size * 0.22).rotationEffect(.degrees(20))
                    }
                    .offset(y: -size * 0.28)
                    HStack(spacing: size * 0.22) {
                        Circle().fill(Color.black.opacity(0.7)).frame(width: size * 0.05, height: size * 0.05)
                        Circle().fill(Color.black.opacity(0.7)).frame(width: size * 0.05, height: size * 0.05)
                    }
                    .offset(y: -size * 0.04)
                }

            case .hog:
                ZStack {
                    Circle().fill(style.tint).frame(width: size * 0.5, height: size * 0.5)
                    HStack(spacing: size * 0.38) {
                        Circle().fill(style.tint).frame(width: size * 0.16, height: size * 0.16)
                        Circle().fill(style.tint).frame(width: size * 0.16, height: size * 0.16)
                    }
                    .offset(y: -size * 0.26)
                    Capsule().fill(Color.black.opacity(0.15)).frame(width: size * 0.2, height: size * 0.14).offset(y: size * 0.12)
                    HStack(spacing: size * 0.06) {
                        Circle().fill(Color.black.opacity(0.6)).frame(width: size * 0.035, height: size * 0.035)
                        Circle().fill(Color.black.opacity(0.6)).frame(width: size * 0.035, height: size * 0.035)
                    }
                    .offset(y: size * 0.12)
                }
            }
        } else {
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Custom silhouette shapes

private struct IngotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.16
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct WheatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        p.move(to: CGPoint(x: midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX, y: rect.minY))

        let grains = 4
        let top = rect.minY + rect.height * 0.06
        let spacing = (rect.height * 0.82) / CGFloat(grains)
        let grainW = rect.width * 0.42
        let grainH = spacing * 0.62

        for i in 0..<grains {
            let y = top + CGFloat(i) * spacing
            p.addEllipse(in: CGRect(x: midX - grainW, y: y, width: grainW, height: grainH))
            p.addEllipse(in: CGRect(x: midX, y: y + spacing * 0.32, width: grainW, height: grainH))
        }
        return p
    }
}
