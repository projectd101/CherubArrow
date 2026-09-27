import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var overlayControllers: [OverlayWindowController] = []
    private var globalClickMonitor: Any?
    private var statusItem: NSStatusItem?
    private let soundManager = SoundManager()
    private let ttsManager = TTSManager()
    private let clickPatternDetector = ClickPatternDetector()
    private let newsManager = NewsManager()
    private let marketPulseManager = MarketPulseManager()
    private let newsMenu = NSMenu()
    private let marketMenu = NSMenu()
    private var preferencesWindowController: PreferencesWindowController?

    // Fallback for burst-triggered speech when no news has loaded yet (offline, first launch, etc.).
    // Once news arrives, bursts read the latest news summaries instead.
    private let demoBurstLines = [
        "Python was named after Monty Python, not the snake.",
        "The first computer bug was an actual moth.",
        "Piper plus runs entirely offline, right here on your Mac."
    ]

    private var isEnabled = true

    // Rapid-fire clicks (fast clicking, drag-selecting text, etc.) landing close
    // together in time were each spawning a full new effect; overlapping while they
    // faded made it look like a single blob/particle "flying" across the screen.
    // This cooldown makes sure each click's effect fully reads as its own discrete pop.
    private var lastEffectTime: TimeInterval = 0
    private let minEffectInterval: TimeInterval = 0.12

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon

        requestAccessibilityPermissionIfNeeded()
        setupOverlayWindows()
        setupStatusItem()
        startGlobalClickMonitor()

        newsManager.onUpdate = { [weak self] in self?.rebuildNewsMenu() }
        newsManager.start()

        marketPulseManager.onUpdate = { [weak self] in self?.rebuildMarketMenu() }
        marketPulseManager.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func requestAccessibilityPermissionIfNeeded() {
        // Global click monitoring requires Accessibility trust.
        // This shows the system prompt the first time the app runs.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    private func setupOverlayWindows() {
        overlayControllers = NSScreen.screens.map { OverlayWindowController(screen: $0) }
        overlayControllers.forEach { $0.showWindow(nil) }
    }

    @objc private func screensChanged() {
        overlayControllers.forEach { $0.close() }
        setupOverlayWindows()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "Click Effects"
        )

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = isEnabled ? .on : .off
        menu.addItem(toggleItem)

        let muteItem = NSMenuItem(title: "Mute Sound", action: #selector(toggleMute), keyEquivalent: "")
        muteItem.target = self
        muteItem.state = soundManager.isMuted ? .on : .off
        menu.addItem(muteItem)

        menu.addItem(.separator())

        let newsItem = NSMenuItem(title: "Latest News", action: nil, keyEquivalent: "")
        newsItem.submenu = newsMenu
        menu.addItem(newsItem)
        rebuildNewsMenu()

        let refreshItem = NSMenuItem(title: "Refresh News", action: #selector(refreshNews), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let marketItem = NSMenuItem(title: "Market Pulse", action: nil, keyEquivalent: "")
        marketItem.submenu = marketMenu
        menu.addItem(marketItem)
        rebuildMarketMenu()

        let refreshMarketItem = NSMenuItem(title: "Refresh Market Pulse", action: #selector(refreshMarketPulse), keyEquivalent: "")
        refreshMarketItem.target = self
        menu.addItem(refreshMarketItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
    }

    @objc private func toggleMute(_ sender: NSMenuItem) {
        soundManager.isMuted.toggle()
        sender.state = soundManager.isMuted ? .on : .off
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(ttsManager: ttsManager)
        }
        preferencesWindowController?.show()
    }

    // MARK: - News

    /// Rebuilds the "Latest News" submenu. Clicking a headline reads its summary aloud.
    private func rebuildNewsMenu() {
        newsMenu.removeAllItems()

        guard !newsManager.headlines.isEmpty else {
            let placeholder = NSMenuItem(title: "Loading news…", action: nil, keyEquivalent: "")
            placeholder.isEnabled = false
            newsMenu.addItem(placeholder)
            return
        }

        for headline in newsManager.headlines {
            let title = headline.headline.count > 70
                ? String(headline.headline.prefix(69)) + "…"
                : headline.headline
            let item = NSMenuItem(title: title, action: #selector(readHeadline(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = headline.summary
            item.toolTip = [headline.source, headline.summary].compactMap { $0 }.joined(separator: " — ")
            newsMenu.addItem(item)
        }
    }

    @objc private func readHeadline(_ sender: NSMenuItem) {
        guard let summary = sender.representedObject as? String else { return }
        ttsManager.speak(summary)
    }

    @objc private func refreshNews() {
        newsManager.refresh()
    }

    // MARK: - Market pulse

    /// Rebuilds the "Market Pulse" submenu. Clicking an event reads it aloud.
    private func rebuildMarketMenu() {
        marketMenu.removeAllItems()

        guard !marketPulseManager.events.isEmpty else {
            let placeholder = NSMenuItem(title: "No market moves yet…", action: nil, keyEquivalent: "")
            placeholder.isEnabled = false
            marketMenu.addItem(placeholder)
            return
        }

        for event in marketPulseManager.events {
            let title = event.ticker.map { "\($0): \(event.factLine)" } ?? event.factLine
            let trimmed = title.count > 70 ? String(title.prefix(69)) + "…" : title
            let item = NSMenuItem(title: trimmed, action: #selector(readMarketEvent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = event.spokenText
            item.toolTip = event.contextLine
            marketMenu.addItem(item)
        }
    }

    @objc private func readMarketEvent(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        ttsManager.speak(text)
    }

    @objc private func refreshMarketPulse() {
        marketPulseManager.refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Global click monitoring

    private func startGlobalClickMonitor() {
        // Fires for clicks in the Dock, Finder desktop, and other apps —
        // NOT for clicks inside our own app, which is fine since we have no UI to click.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.handleGlobalClick(at: NSEvent.mouseLocation)
        }
    }

    private func handleGlobalClick(at screenPoint: NSPoint) {
        guard isEnabled else { return }

        let now = Date().timeIntervalSinceReferenceDate

        // Which screen (for multi-monitor setups) and which half of it the click
        // landed in. Each screen is split vertically down its own center, so this
        // works correctly per-display rather than across the combined desktop.
        let screen = NSScreen.screens.first(where: { NSMouseInRect(screenPoint, $0.frame, false) })
        let zone: ClickPatternDetector.Zone = {
            guard let screen = screen else { return .left }
            return screenPoint.x < screen.frame.midX ? .left : .right
        }()

        // Pattern detection sees every real click, independent of the visual
        // effect's own throttle below — burst timing needs true click timing.
        let trigger = clickPatternDetector.registerClick(at: now, zone: zone)
        switch trigger {
        case .affirmation:
            soundManager.playRandomAffirmation()
        case .news:
            // Left-side double-click: read the news the user follows.
            if let line = newsManager.nextSummaryToSpeak() ?? demoBurstLines.randomElement() {
                ttsManager.speak(line)
            }
        case .marketPulse:
            // Right-side double-click: read the latest followed market move
            // (crypto/stocks/Polymarket — whatever marketPulseManager has queued).
            if let line = marketPulseManager.nextEventToSpeak() {
                ttsManager.speak(line)
            } else {
                ttsManager.speak("No notable market moves right now.")
            }
        case .none:
            break
        }

        // Visual effect keeps its own separate cooldown so rapid clicks don't spawn
        // overlapping/jumbled particle effects.
        guard now - lastEffectTime > minEffectInterval else { return }
        lastEffectTime = now

        guard let screen = screen else { return }
        guard let controller = overlayControllers.first(where: { $0.screen == screen }) else { return }
        controller.overlayView.triggerClickEffect(atScreenPoint: screenPoint)
    }
}
