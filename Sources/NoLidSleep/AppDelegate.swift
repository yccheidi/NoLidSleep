import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var disabled = false          // current SleepDisabled
    private var ruleInstalled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        refresh()
        applyLaunchBehavior()

        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    // MARK: - State

    private func refresh() {
        disabled = Pmset.isSleepDisabled() ?? disabled
        ruleInstalled = Pmset.canToggleWithoutPassword()
        updateIcon()
    }

    private func tick() {
        let before = disabled
        refresh()
        if disabled != before { Settings.lastState = disabled }
        checkBattery()
    }

    private func applyLaunchBehavior() {
        guard ruleInstalled else { return }
        let target: Bool
        switch Settings.launchBehavior {
        case .on: target = true
        case .off: target = false
        case .last: target = Settings.lastState
        }
        if target != disabled { set(target) }
    }

    private func checkBattery() {
        guard disabled, Settings.lowBatteryProtection,
              let b = Battery.status(), !b.onAC, b.percent <= Settings.lowBatteryThreshold else { return }
        _ = b
        set(false)
    }

    @discardableResult
    private func set(_ on: Bool) -> Bool {
        if !ruleInstalled {
            guard installRuleInteractively() else { return false }
        }
        let ok = Pmset.setSleepDisabled(on)
        refresh()
        if ok { Settings.lastState = disabled }
        return ok
    }

    private func installRuleInteractively() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "One-time setup"
        alert.informativeText = "NoLidSleep needs to add a sudoers rule so it can run only “pmset disablesleep 0/1” without asking for a password each time. You'll be asked for your admin password once."
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
        let name = disabled ? "laptopcomputer" : "laptopcomputer.slash"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "NoLidSleep")
            ?? NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "NoLidSleep")
        img?.isTemplate = true
        button.image = img
        button.toolTip = disabled ? "Lid-closed sleep disabled (SleepDisabled = 1)" : "Lid-closed sleep allowed (SleepDisabled = 0)"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        menu.removeAllItems()

        let status = NSMenuItem(title: disabled ? "Awake with lid closed" : "Sleeps normally when lid closes", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let toggle = NSMenuItem(title: "Keep Awake with Lid Closed", action: #selector(toggleSleep), keyEquivalent: "")
        toggle.target = self
        toggle.state = disabled ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = Settings.launchAtLogin ? .on : .off
        menu.addItem(login)

        let behaviorItem = NSMenuItem(title: "On Launch", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for b in LaunchBehavior.allCases {
            let item = NSMenuItem(title: b.title, action: #selector(pickBehavior(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = b.rawValue
            item.state = Settings.launchBehavior == b ? .on : .off
            sub.addItem(item)
        }
        behaviorItem.submenu = sub
        menu.addItem(behaviorItem)

        if Battery.status() != nil {
            let bat = NSMenuItem(title: "Turn Off Below \(Settings.lowBatteryThreshold)% Battery", action: #selector(toggleBattery), keyEquivalent: "")
            bat.target = self
            bat.state = Settings.lowBatteryProtection ? .on : .off
            menu.addItem(bat)
        }
        menu.addItem(.separator())

        let rule = NSMenuItem(
            title: ruleInstalled ? "Remove Passwordless Rule…" : "Set Up Passwordless Toggle…",
            action: #selector(toggleRule), keyEquivalent: "")
        rule.target = self
        menu.addItem(rule)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit NoLidSleep", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleSleep() { set(!disabled) }
    @objc private func toggleLogin() { Settings.launchAtLogin.toggle() }
    @objc private func toggleBattery() { Settings.lowBatteryProtection.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func pickBehavior(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let b = LaunchBehavior(rawValue: raw) {
            Settings.launchBehavior = b
        }
    }

    @objc private func toggleRule() {
        if ruleInstalled {
            _ = Pmset.removeRule()
            ruleInstalled = Pmset.canToggleWithoutPassword()
        } else {
            _ = installRuleInteractively()
        }
    }
}
