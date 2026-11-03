import AppKit

/// Small frosted-glass popup shown under the menu bar icon when the state changes.
final class Toast {
    private var window: NSWindow?
    private var generation = 0

    func show(_ text: String, below button: NSStatusBarButton?) {
        guard let buttonWindow = button?.window else { return }
        generation += 1
        let gen = generation
        window?.orderOut(nil)

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.sizeToFit()

        let pad = NSSize(width: 16, height: 9)
        let size = NSSize(width: label.frame.width + pad.width * 2, height: label.frame.height + pad.height * 2)

        let glass = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 11
        glass.layer?.masksToBounds = true
        label.frame.origin = NSPoint(x: pad.width, y: pad.height)
        glass.addSubview(label)

        let f = buttonWindow.frame
        var x = f.midX - size.width / 2
        if let screen = buttonWindow.screen {
            x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
        }
        let origin = NSPoint(x: x, y: f.minY - size.height - 6)

        let w = NSWindow(contentRect: NSRect(origin: origin, size: size), styleMask: .borderless,
                         backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .statusBar
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        w.contentView = glass
        w.alphaValue = 0
        w.orderFrontRegardless()
        window = w

        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; w.animator().alphaValue = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self, weak w] in
            guard let self, let w, self.generation == gen else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; w.animator().alphaValue = 0 },
                                                 completionHandler: { if self.generation == gen { w.orderOut(nil) } })
        }
    }
}
