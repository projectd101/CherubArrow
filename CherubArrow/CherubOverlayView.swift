import Cocoa

/// Draws playful, colorful effects at the cursor on every click:
/// sparkle stars, candy bursts, and confetti — one picked at random.
final class ClickEffectsView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum EffectType: CaseIterable {
        case sparkleStars
        case candyBurst
        case confetti
    }

    /// screenPoint is in AppKit screen coordinates (origin bottom-left — same as NSScreen.frame / NSEvent.mouseLocation).
    /// Purely visual — no audio decision happens here. What (if anything) plays on a
    /// given click is decided separately by ClickPatternDetector in AppDelegate, since
    /// audio triggers on a different rhythm than the visual effect (which fires every click).
    func triggerClickEffect(atScreenPoint screenPoint: NSPoint) {
        guard let windowFrame = window?.frame else { return }

        // This view's layer uses a bottom-left origin, same as screenPoint — no flip needed.
        let point = CGPoint(
            x: screenPoint.x - windowFrame.origin.x,
            y: screenPoint.y - windowFrame.origin.y
        )

        switch EffectType.allCases.randomElement() ?? .sparkleStars {
        case .sparkleStars:
            spawnEmojiBurst(at: point, emojis: ["✨", "⭐️", "🌟"], count: 3)
        case .candyBurst:
            spawnEmojiBurst(at: point, emojis: ["🍬", "🍭", "🧁", "🍫", "🍩"], count: 5)
        case .confetti:
            spawnConfetti(at: point)
        }
    }

    // MARK: - Emoji burst (stars / candy)

    /// Particles pop outward a short, EVEN distance in evenly-spaced directions
    /// (plus a little jitter) rather than fully random angles/distances — this is
    /// what stops random chance from occasionally sending most particles the same
    /// way and reading as a single object "flying across" the screen.
    private func spawnEmojiBurst(at point: CGPoint, emojis: [String], count: Int) {
        let baseAngle = CGFloat.random(in: 0...(2 * .pi)) // rotate the whole burst pattern each time
        for i in 0..<count {
            let piece = CATextLayer()
            piece.string = emojis.randomElement()
            let size = CGFloat.random(in: 10...16) // was 18...28 — much smaller
            piece.fontSize = size
            piece.alignmentMode = .center
            piece.frame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
            piece.contentsScale = window?.backingScaleFactor ?? 2
            layer?.addSublayer(piece)

            let slice = (2 * CGFloat.pi) / CGFloat(count)
            let angle = baseAngle + slice * CGFloat(i) + CGFloat.random(in: -0.2...0.2)
            let distance = CGFloat.random(in: 12...22) // was 30...80 — tight burst around the click point
            let duration = TimeInterval.random(in: 0.4...0.55)

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = piece.position
            move.toValue = CGPoint(x: piece.position.x + cos(angle) * distance,
                                    y: piece.position.y + sin(angle) * distance)
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.4, 1.1, 0.9]
            scale.keyTimes = [0, 0.4, 1.0]

            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.fromValue = 0
            rotate.toValue = CGFloat.random(in: -1.0...1.0)

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.1, 0.6, 1.0]

            addGroup([move, scale, rotate, fade], to: piece, duration: duration)
        }
    }

    // MARK: - Confetti

    private func spawnConfetti(at point: CGPoint) {
        let colors: [NSColor] = [.systemPink, .systemYellow, .systemTeal, .systemPurple, .systemOrange, .systemGreen]

        for _ in 0..<10 {
            let w = CGFloat.random(in: 3...5) // was 4...7
            let h = CGFloat.random(in: 6...9) // was 8...12

            let piece = CALayer()
            piece.frame = CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)
            piece.backgroundColor = colors.randomElement()?.cgColor
            piece.cornerRadius = 1.5
            layer?.addSublayer(piece)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 20...45) // was 40...100
            let duration = TimeInterval.random(in: 0.5...0.75)

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = piece.position
            move.toValue = CGPoint(x: piece.position.x + cos(angle) * distance,
                                    y: piece.position.y + sin(angle) * distance)
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.fromValue = 0
            rotate.toValue = CGFloat.random(in: -3...3)

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.1, 0.6, 1.0]

            addGroup([move, rotate, fade], to: piece, duration: duration)
        }
    }

    // MARK: - Shared animation helper

    private func addGroup(_ animations: [CAAnimation], to layer: CALayer, duration: TimeInterval) {
        for anim in animations { anim.duration = duration }
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        layer.add(group, forKey: "effect")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            layer.removeFromSuperlayer()
        }
    }
}
