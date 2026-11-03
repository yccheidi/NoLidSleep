import AppKit

/// Hand-drawn menu bar template icons (20x18 pt), one per mode:
///  off   - open laptop, hollow screen
///  awake - open laptop, lit (filled) screen
///  lid   - closed laptop with a sun above it (running with the lid shut)
enum Icons {
    static func image(for mode: Mode) -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.set()
            switch mode {
            case .off, .awake: drawOpenLaptop(filled: mode == .awake)
            case .lid: drawClosedLaptopWithSun()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    private static func drawOpenLaptop(filled: Bool) {
        let screen = NSRect(x: 3, y: 7, width: 14, height: 9)
        if filled {
            NSBezierPath(roundedRect: screen, xRadius: 1.8, yRadius: 1.8).fill()
        } else {
            let p = NSBezierPath(roundedRect: screen.insetBy(dx: 0.7, dy: 0.7), xRadius: 1.4, yRadius: 1.4)
            p.lineWidth = 1.4
            p.stroke()
        }
        NSBezierPath(roundedRect: NSRect(x: 0.8, y: 3.5, width: 18.4, height: 2.4), xRadius: 1.2, yRadius: 1.2).fill()
    }

    private static func drawClosedLaptopWithSun() {
        // closed laptop: a flat slab
        NSBezierPath(roundedRect: NSRect(x: 0.8, y: 2.2, width: 18.4, height: 4), xRadius: 1.8, yRadius: 1.8).fill()
        // sun above it
        let c = NSPoint(x: 10, y: 12.2)
        NSBezierPath(ovalIn: NSRect(x: c.x - 2.6, y: c.y - 2.6, width: 5.2, height: 5.2)).fill()
        let rays = NSBezierPath()
        rays.lineWidth = 1.4
        rays.lineCapStyle = .round
        for i in 0..<8 where i != 6 {
            let a = CGFloat(i) * .pi / 4
            rays.move(to: NSPoint(x: c.x + cos(a) * 4.3, y: c.y + sin(a) * 4.3))
            rays.line(to: NSPoint(x: c.x + cos(a) * 5.9, y: c.y + sin(a) * 5.9))
        }
        rays.stroke()
    }
}
