import AppKit

enum AppInfo {
    static let repoSlug = "yccheidi/NoLidSleep"
    static let repoURL = URL(string: "https://github.com/\(repoSlug)")!
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
}

enum About {
    static func show() {
        let credits = NSMutableAttributedString(
            string: "Keep your Mac awake with the lid open or closed.\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        credits.append(NSAttributedString(
            string: AppInfo.repoURL.absoluteString,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: AppInfo.repoURL]))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "NoLidSleep",
            .applicationVersion: AppInfo.version,
            .version: "",
            .credits: credits,
        ])
    }
}

/// Checks the latest GitHub release and compares it with the running version.
enum UpdateChecker {
    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }

    static func check() {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(AppInfo.repoSlug)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let data, status == 200, let rel = try? JSONDecoder().decode(Release.self, from: data) {
                    let latest = rel.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                    if isNewer(latest, than: AppInfo.version) {
                        offer(latest: latest, page: URL(string: rel.html_url) ?? AppInfo.repoURL)
                    } else {
                        info("You're up to date", "NoLidSleep \(AppInfo.version) is the latest version.")
                    }
                } else if status == 404 {
                    info("Couldn't check for updates",
                         "No public release was found. If the repository is private, check \(AppInfo.repoURL.absoluteString)/releases manually.")
                } else {
                    info("Couldn't check for updates", error?.localizedDescription ?? "GitHub returned status \(status).")
                }
            }
        }.resume()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func offer(latest: String, page: URL) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "NoLidSleep \(latest) is available"
        alert.informativeText = "You have \(AppInfo.version). Open the release page to download the new version."
        alert.addButton(withTitle: "Open Release Page")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(page) }
    }

    private static func info(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
