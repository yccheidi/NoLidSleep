import Foundation
import IOKit.ps
import ServiceManagement

enum LaunchBehavior: String, CaseIterable {
    case on, off, last

    var title: String {
        switch self {
        case .on: return "Start Awake"
        case .off: return "Start Off"
        case .last: return "Remember Last State"
        }
    }
}

/// Session length choices. 0 = infinite.
enum Duration {
    static let options: [(title: String, seconds: Int)] = [
        ("15 Minutes", 15 * 60),
        ("30 Minutes", 30 * 60),
        ("1 Hour", 3600),
        ("2 Hours", 2 * 3600),
        ("4 Hours", 4 * 3600),
        ("8 Hours", 8 * 3600),
        ("12 Hours", 12 * 3600),
        ("Infinite", 0),
    ]
}

enum Settings {
    private static let d = UserDefaults.standard

    static var launchBehavior: LaunchBehavior {
        get { LaunchBehavior(rawValue: d.string(forKey: "launchBehavior") ?? "") ?? .last }
        set { d.set(newValue.rawValue, forKey: "launchBehavior") }
    }

    /// Whether the session was active when the user last changed it.
    static var lastActive: Bool {
        get { d.bool(forKey: "lastActive") }
        set { d.set(newValue, forKey: "lastActive") }
    }

    /// Also keep the Mac running when the lid is closed (pmset disablesleep 1) while active.
    static var lidMode: Bool {
        get { d.bool(forKey: "lidMode") }
        set { d.set(newValue, forKey: "lidMode") }
    }

    static var keepDisplayOn: Bool {
        get { d.object(forKey: "keepDisplayOn") as? Bool ?? true }
        set { d.set(newValue, forKey: "keepDisplayOn") }
    }

    /// Seconds; 0 = infinite.
    static var duration: Int {
        get { d.object(forKey: "duration") as? Int ?? 0 }
        set { d.set(newValue, forKey: "duration") }
    }

    static var lowBatteryProtection: Bool {
        get { d.object(forKey: "lowBattery") as? Bool ?? true }
        set { d.set(newValue, forKey: "lowBattery") }
    }

    static let lowBatteryThreshold = 20

    static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login failed: \(error)")
            }
        }
    }
}

enum Battery {
    /// (percent, onACPower). nil on desktops without a battery.
    static func status() -> (percent: Int, onAC: Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (cur * 100 / max, onAC)
        }
        return nil
    }
}
