import Foundation
import IOKit.ps
import ServiceManagement

/// The three states, in increasing strength.
enum Mode: String {
    case off, awake, lid

    var toast: String {
        switch self {
        case .off: return "Sleep allowed"
        case .awake: return "Awake"
        case .lid: return "Awake, even with lid closed"
        }
    }
}

enum LaunchBehavior: String, CaseIterable {
    case off, awake, lid, last

    var title: String {
        switch self {
        case .off: return "Start Off"
        case .awake: return "Start Awake"
        case .lid: return "Start Awake, Even Lid Closed"
        case .last: return "Remember Last State"
        }
    }
}

/// Session length choices. 0 = infinite.
enum Duration {
    static let options: [(title: String, seconds: Int)] = [
        ("30 Minutes", 30 * 60),
        ("1 Hour", 3600),
        ("3 Hours", 3 * 3600),
        ("5 Hours", 5 * 3600),
        ("12 Hours", 12 * 3600),
        ("Infinite", 0),
    ]

    static func title(_ seconds: Int) -> String {
        options.first { $0.seconds == seconds }?.title ?? "Infinite"
    }
}

enum Settings {
    private static let d = UserDefaults.standard

    static var launchBehavior: LaunchBehavior {
        get { LaunchBehavior(rawValue: d.string(forKey: "launchBehavior") ?? "") ?? .last }
        set { d.set(newValue.rawValue, forKey: "launchBehavior") }
    }

    /// Last mode and duration the user picked (used by "Remember Last State").
    static var lastMode: Mode {
        get { Mode(rawValue: d.string(forKey: "lastMode") ?? "") ?? .off }
        set { d.set(newValue.rawValue, forKey: "lastMode") }
    }

    static var lastDuration: Int {
        get { d.object(forKey: "lastDuration") as? Int ?? 0 }
        set { d.set(newValue, forKey: "lastDuration") }
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
