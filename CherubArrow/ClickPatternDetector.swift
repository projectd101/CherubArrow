import Foundation

/// Decides what audio, if any, should play in response to a click.
/// Completely independent of the visual click effect, which still fires on every click.
///
/// The screen is split into a left half and a right half (see AppDelegate, which
/// determines the zone from the click's x-position relative to the screen it landed
/// on). Each half tracks its own double-click burst independently, so a quick
/// double-click on the left always means "read my news" and on the right always
/// means "read my market pulse" — clicks on one side never count toward a burst on
/// the other.
final class ClickPatternDetector {

    enum Zone {
        case left
        case right
    }

    enum Trigger {
        case none
        case news
        case marketPulse
        case affirmation
    }

    // MARK: - Burst detection (2 clicks within a window, per zone)

    private var recentLeftClickTimestamps: [TimeInterval] = []
    private var recentRightClickTimestamps: [TimeInterval] = []
    private let burstWindow: TimeInterval = 0.5        // clicks must land within this window of each other
    private let burstTargetCount = 2                   // how many quick clicks (on the same side) fire the burst
    private var lastLeftBurstFireTime: TimeInterval = 0
    private var lastRightBurstFireTime: TimeInterval = 0
    private let burstCooldown: TimeInterval = 2.0       // don't re-fire on clicks 3/4/5 of the same flurry

    // MARK: - Affirmation spacing (side-independent — any click counts)

    private var lastAffirmationTime: TimeInterval = 0
    private let minAffirmationGap: TimeInterval = 90.0  // never more often than every 90s
    private let affirmationChance: Double = 0.05        // 5% roll on eligible clicks

    /// Call once per physical click, with the click's own timestamp (not throttled by
    /// the visual effect's cooldown — pattern detection needs real click timing) and
    /// the screen half it landed in.
    func registerClick(at time: TimeInterval = Date().timeIntervalSinceReferenceDate, zone: Zone) -> Trigger {
        switch zone {
        case .left:
            recentLeftClickTimestamps.removeAll { time - $0 > burstWindow }
            recentLeftClickTimestamps.append(time)

            print("🖱️ left click at \(time), recentCount=\(recentLeftClickTimestamps.count)")

            if recentLeftClickTimestamps.count >= burstTargetCount,
               time - lastLeftBurstFireTime > burstCooldown {
                lastLeftBurstFireTime = time
                recentLeftClickTimestamps.removeAll()
                print("🖱️ -> FIRED news (left double-click)")
                return .news
            }

        case .right:
            recentRightClickTimestamps.removeAll { time - $0 > burstWindow }
            recentRightClickTimestamps.append(time)

            print("🖱️ right click at \(time), recentCount=\(recentRightClickTimestamps.count)")

            if recentRightClickTimestamps.count >= burstTargetCount,
               time - lastRightBurstFireTime > burstCooldown {
                lastRightBurstFireTime = time
                recentRightClickTimestamps.removeAll()
                print("🖱️ -> FIRED marketPulse (right double-click)")
                return .marketPulse
            }
        }

        guard time - lastAffirmationTime > minAffirmationGap else { return .none }
        guard Double.random(in: 0...1) < affirmationChance else { return .none }

        lastAffirmationTime = time
        return .affirmation
    }
}
