import AppKit
import IOKit.pwr_mgt

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let toast = Toast()
    private var timer: Timer?
    private var tickCount = 0

    // Session
    private var mode: Mode = .off
    private var duration = 0                 // seconds, 0 = infinite
    private var endDate: Date?
    private var assertions: [IOPMAssertionID] = []
    private var weSetLid = false

    // Observed system state
    private var lidSleepDisabled = false     // pmset SleepDisabled
    private var ruleInstalled = false

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        statusItem.menu = menu
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
        case .awake: start(.awake, seconds: Settings.lastDuration, announce: false)
        case .lid: start(.lid, seconds: Settings.lastDuration, announce: false)
        case .last:
            if Settings.lastMode != .off { start(Settings.lastMode, seconds: Settings.lastDuration, announce: false) }
            else { clearStaleLid() }
        case .off: clearStaleLid()
        }
    }

    /// After a crash or reboot SleepDisabled can still be 1 while we're off.
    private func clearStaleLid() {
        if lidSleepDisabled && ruleInstalled { Pmset.setSleepDisabled(false); pollSystem() }
    }

    // MARK: - Tick

    private func tick() {
        tickCount += 1
        if mode != .off, let end = endDate, Date() >= end { stop() }
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
        guard mode != .off, Settings.lowBatteryProtection,
              let b = Battery.status(), !b.onAC, b.percent <= Settings.lowBatteryThreshold else { return }
        stop()
    }

    // MARK: - Session control

    private func start(_ newMode: Mode, seconds: Int, announce: Bool = true) {
        guard newMode != .off else { stop(); return }
        if newMode == .lid && !ruleInstalled && !installRuleInteractively() { return }

        createAssertions()
        mode = newMode
        duration = seconds
        endDate = seconds > 0 ? Date().addingTimeInterval(TimeInterval(seconds)) : nil
        Settings.lastMode = newMode
        Settings.lastDuration = seconds
        syncLid()
        updateIcon()
        if announce { announceState() }
    }

    private func stop() {
        releaseAssertions()
        mode = .off
        endDate = nil
        Settings.lastMode = .off
        syncLid()
        updateIcon()
        announceState()
    }

    /// Makes `pmset disablesleep` match the current mode.
    private func syncLid() {
        if mode == .lid {
            weSetLid = true
            if !lidSleepDisabled { Pmset.setSleepDisabled(true) }
        } else if weSetLid {
            weSetLid = false
            if ruleInstalled { Pmset.setSleepDisabled(false) }
        }
        pollSystem()
    }

    private func announceState() {
        var text = mode.toast
        if mode != .off { text += " · " + Duration.title(duration) }
        toast.show(text, below: statusItem.button)
    }

    private func createAssertions() {
        releaseAssertions()
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep] {
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
        // Reflect reality: SleepDisabled=1 always shows the lid icon.
        let name: String
        if mode == .lid || (mode == .off && lidSleepDisabled) { name = "laptopcomputer" }
        else if mode == .awake { name = "sun.max.fill" }
        else { name = "moon.zzz" }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "NoLidSleep")
        img?.isTemplate = true
        button.image = img
        button.toolTip = statusText()
    }

    private func statusText() -> String {
        guard mode != .off else {
            return lidSleepDisabled ? "Off · lid sleep still disabled by something else" : "Off · sleep allowed"
        }
        let base = mode == .lid ? "Awake, even lid closed" : "Awake"
        if let end = endDate { return "\(base) · \(Self.format(end.timeIntervalSinceNow)) left" }
        return "\(base) · until turned off"
    }

    private static func format(_ interval: TimeInterval) -> String {
        let mins = Int((max(interval, 0) / 60).rounded(.up))
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(max(mins, 1))m"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        pollSystem()
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let off = add(menu, "Sleep Allowed (Off)", #selector(pickOff))
        off.state = mode == .off ? .on : .off
        menu.addItem(durationMenuItem("Disable Sleep", .awake))
        menu.addItem(durationMenuItem("Disable Sleep, Even Lid Closed", .lid))
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
            let bat = add(menu, "Stop Below \(Settings.lowBatteryThreshold)% Battery", #selector(menuToggleBattery))
            bat.state = Settings.lowBatteryProtection ? .on : .off
        }
        if ruleInstalled { add(menu, "Remove Lid Permission…", #selector(menuRemoveRule)) }
        menu.addItem(.separator())
        let quit = add(menu, "Quit NoLidSleep", #selector(menuQuit))
        quit.keyEquivalent = "q"
    }

    private func durationMenuItem(_ title: String, _ target: Mode) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.state = mode == target ? .on : .off
        let sub = NSMenu()
        for opt in Duration.options {
            let d = add(sub, opt.title, #selector(pickDuration(_:)))
            d.tag = opt.seconds
            d.representedObject = target.rawValue
            d.state = (mode == target && duration == opt.seconds) ? .on : .off
        }
        item.submenu = sub
        return item
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func pickOff() { stop() }

    @objc private func pickDuration(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let m = Mode(rawValue: raw) else { return }
        start(m, seconds: sender.tag)
    }

    @objc private func menuToggleLogin() { Settings.launchAtLogin.toggle() }
    @objc private func menuToggleBattery() { Settings.lowBatteryProtection.toggle() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    @objc private func pickBehavior(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let b = LaunchBehavior(rawValue: raw) {
            Settings.launchBehavior = b
        }
    }

    @objc private func menuRemoveRule() {
        if mode == .lid { stop() }
        _ = Pmset.removeRule()
        ruleInstalled = Pmset.canToggleWithoutPassword()
    }
}
