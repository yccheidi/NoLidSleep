import Foundation
import IOKit.ps
import ServiceManagement

enum LaunchBehavior: String, CaseIterable {
    case on, off, last

    var title: String {
        switch self {
        case .on: return "Turn On"
        case .off: return "Turn Off"
        case .last: return "Remember Last State"
        }
    }
}

enum Settings {
    private static let d = UserDefaults.standard

    static var launchBehavior: LaunchBehavior {
        get { LaunchBehavior(rawValue: d.string(forKey: "launchBehavior") ?? "") ?? .last }
        set { d.set(newValue.rawValue, forKey: "launchBehavior") }
    }

    /// Last state the app saw or set (true = lid-closed sleep disabled).
    static var lastState: Bool {
        get { d.bool(forKey: "lastState") }
        set { d.set(newValue, forKey: "lastState") }
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
