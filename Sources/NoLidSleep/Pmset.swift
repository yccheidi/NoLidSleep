import Foundation

/// Thin wrapper around `pmset` and the sudoers rule that lets us toggle it without a password.
enum Pmset {
    private static let pmsetPath = "/usr/bin/pmset"
    private static let sudoersPath = "/etc/sudoers.d/nolidsleep"

    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Current `SleepDisabled` value. nil if it can't be read.
    static func isSleepDisabled() -> Bool? {
        let (status, out) = run(pmsetPath, ["-g"])
        guard status == 0 else { return nil }
        for line in out.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
        }
        // Key absent means the default (sleep allowed).
        return false
    }

    /// True when the passwordless sudoers rule is installed and working.
    static func canToggleWithoutPassword() -> Bool {
        run("/usr/bin/sudo", ["-n", "-l", pmsetPath, "disablesleep", "1"]).status == 0
    }

    @discardableResult
    static func setSleepDisabled(_ disabled: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", pmsetPath, "disablesleep", disabled ? "1" : "0"]).status == 0
    }

    // MARK: - sudoers rule (only allows `pmset disablesleep 0|1`)

    @discardableResult
    static func installRule() -> Bool {
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: \(pmsetPath) disablesleep 0, \(pmsetPath) disablesleep 1"
        let script = """
        tmp=$(/usr/bin/mktemp) && \
        echo '\(rule)' > "$tmp" && \
        /usr/sbin/visudo -cf "$tmp" >/dev/null && \
        /usr/bin/install -m 440 -o root -g wheel "$tmp" \(sudoersPath); \
        rc=$?; /bin/rm -f "$tmp"; exit $rc
        """
        return runAsAdmin(script)
    }

    @discardableResult
    static func removeRule() -> Bool {
        runAsAdmin("/bin/rm -f \(sudoersPath)")
    }

    private static func runAsAdmin(_ shell: String) -> Bool {
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let apple = "do shell script \"\(escaped)\" with administrator privileges"
        return run("/usr/bin/osascript", ["-e", apple]).status == 0
    }
}
