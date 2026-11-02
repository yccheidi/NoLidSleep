import AppKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var tickCount = 0

    // Session
    private var active = false
    private var endDate: Date?
    private var assertions: [IOPMAssertionID] = []
    private var weSetLid = false

    // Observed system state
    private var lidSleepDisabled = false   // pmset SleepDisabled
    private var ruleInstalled = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        pollSystem()
        applyLaunchBehavior()
        updateIcon()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseAssertions()
        if weSetLid { Pmset.setSleepDisabled(false) }
    }

    private func applyLaunchBehavior() {
        switch Settings.launchBehavior {
        case .on:
            activate()
        case .last:
            if Settings.lastActive { activate() } else { clearStaleLid() }
        case .off:
            clearStaleLid()
        }
    }

    /// After a crash or reboot SleepDisabled can still be 1 while we're inactive.
    private func clearStaleLid() {
        if lidSleepDisabled && ruleInstalled { Pmset.setSleepDisabled(false); pollSystem() }
    }

    // MARK: - Tick

    private func tick() {
        tickCount += 1
        if active, let end = endDate, Date() >= end {
            deactivate(userInitiated: false)
        }
        if tickCount % 3 == 0 {
            pollSystem()
            checkBattery()
        }
        updateIcon()
    }

    private func pollSystem() {
        lidSleepDisabled = Pmset.isSleepDisabled() ?? lidSleepDisabled
        ruleInstalled = Pmset.canToggleWithoutPassword()
    }

    private func checkBattery() {
        guard active, Settings.lowBatteryProtection,
              let b = Battery.status(), !b.onAC, b.percent <= Settings.lowBatteryThreshold else { return }
        deactivate(userInitiated: false)
    }

    // MARK: - Session control

    private func toggleActive() {
        if active { deactivate(userInitiated: true) } else { activate() }
    }

    private func activate() {
        createAssertions()
        active = true
        startTimer()
        Settings.lastActive = true
        applyLid()
        updateIcon()
    }

    private func deactivate(userInitiated: Bool) {
        releaseAssertions()
        active = false
        endDate = nil
        Settings.lastActive = false
        applyLid()
        updateIcon()
    }

    private func startTimer() {
        let secs = Settings.duration
        endDate = secs > 0 ? Date().addingTimeInterval(TimeInterval(secs)) : nil
    }

    /// Syncs `pmset disablesleep` with (active && lidMode).
    private func applyLid() {
        let want = active && Settings.lidMode
        if want {
            if !ruleInstalled && !installRuleInteractively() {
                Settings.lidMode = false
                return
            }
            weSetLid = true
            if !lidSleepDisabled { Pmset.setSleepDisabled(true) }
        } else if weSetLid {
            weSetLid = false
            if ruleInstalled { Pmset.setSleepDisabled(false) }
        }
        pollSystem()
    }

    private func createAssertions() {
        releaseAssertions()
        var types = [kIOPMAssertionTypePreventUserIdleSystemSleep as String]
        if Settings.keepDisplayOn { types.append(kIOPMAssertionTypePreventUserIdleDisplaySleep as String) }
        for type in types {
            var id: IOPMAssertionID = 0
            let r = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                "NoLidSleep keeping Mac awake" as CFString, &id)
            if r == kIOReturnSuccess { assertions.append(id) }
        }
    }

    private func releaseAssertions() {
        assertions.forEach { IOPMAssertionRelease($0) }
        assertions.removeAll()
    }

    private func installRuleInteractively() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "One-time setup"
        alert.informativeText = "To keep your Mac awake with the lid closed, NoLidSleep needs a sudoers rule that allows only “pmset disablesleep 0/1” without a password. You'll be asked for your admin password once."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        _ = Pmset.installRule()
        ruleInstalled = Pmset.canToggleWithoutPassword()
        return ruleInstalled
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        if lidSleepDisabled { name = "laptopcomputer" }
        else { name = active ? "cup.and.saucer.fill" : "cup.and.saucer" }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "NoLidSleep")
            ?? NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "NoLidSleep")
        img?.isTemplate = true
        button.image = img
        button.toolTip = statusText()
    }

    private func statusText() -> String {
        var s: String
        if active {
            if let end = endDate { s = "Awake · \(Self.format(end.timeIntervalSinceNow)) left" }
            else { s = "Awake · until turned off" }
        } else {
            s = "Off"
        }
        if lidSleepDisabled { s += " · lid closed won't sleep" }
        return s
    }

    private static func format(_ interval: TimeInterval) -> String {
        let mins = Int((max(interval, 0) / 60).rounded(.up))
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(max(mins, 1))m"
    }

    // MARK: - Click / Menu

    @objc private func statusClicked(_ sender: NSStatusBarButton) {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleActive()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pollSystem()
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        add(menu, active ? "Turn Off" : "Keep Mac Awake", #selector(menuToggleActive))

        let lid = add(menu, "Also Keep Awake with Lid Closed", #selector(menuToggleLid))
        lid.state = Settings.lidMode ? .on : .off
        lid.isEnabled = active
        lid.indentationLevel = 1

        let durationItem = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        let durationMenu = NSMenu()
        for opt in Duration.options {
            let item = add(durationMenu, opt.title, #selector(pickDuration(_:)))
            item.tag = opt.seconds
            item.state = Settings.duration == opt.seconds ? .on : .off
        }
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        let disp = add(menu, "Keep Display On", #selector(menuToggleDisplay))
        disp.state = Settings.keepDisplayOn ? .on : .off
        menu.addItem(.separator())

        let login = add(menu, "Launch at Login", #selector(menuToggleLogin))
        login.state = Settings.launchAtLogin ? .on : .off

        let behaviorItem = NSMenuItem(title: "On Launch", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for b in LaunchBehavior.allCases {
            let item = add(sub, b.title, #selector(pickBehavior(_:)))
            item.representedObject = b.rawValue
            item.state = Settings.launchBehavior == b ? .on : .off
        }
        behaviorItem.submenu = sub
        menu.addItem(behaviorItem)

        if Battery.status() != nil {
            let bat = add(menu, "Turn Off Below \(Settings.lowBatteryThreshold)% Battery", #selector(menuToggleBattery))
            bat.state = Settings.lowBatteryProtection ? .on : .off
        }
        menu.addItem(.separator())

        add(menu, ruleInstalled ? "Remove Passwordless Rule…" : "Set Up Lid Mode Permission…", #selector(menuToggleRule))
        menu.addItem(.separator())
        let quit = add(menu, "Quit NoLidSleep", #selector(menuQuit))
        quit.keyEquivalent = "q"
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func menuToggleActive() { toggleActive() }

    @objc private func menuToggleLid() {
        guard active else { return }
        Settings.lidMode.toggle()
        applyLid()
        updateIcon()
    }

    @objc private func pickDuration(_ sender: NSMenuItem) {
        Settings.duration = sender.tag
        if active { startTimer() }
        updateIcon()
    }

    @objc private func menuToggleDisplay() {
        Settings.keepDisplayOn.toggle()
        if active { createAssertions() }
    }

    @objc private func menuToggleLogin() { Settings.launchAtLogin.toggle() }
    @objc private func menuToggleBattery() { Settings.lowBatteryProtection.toggle() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    @objc private func pickBehavior(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let b = LaunchBehavior(rawValue: raw) {
            Settings.launchBehavior = b
        }
    }

    @objc private func menuToggleRule() {
        if ruleInstalled {
            _ = Pmset.removeRule()
            ruleInstalled = Pmset.canToggleWithoutPassword()
        } else {
            _ = installRuleInteractively()
        }
    }
}
