import AppKit

/// Menu bar template icons, one per mode:
///  off   - moon and stars (SF Symbol)
///  awake - open laptop with a sun behind it
///  lid   - closed laptop with a sun above it
enum Icons {
    static func image(for mode: Mode) -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.set()
            switch mode {
            case .off: drawMoonStars()
            case .awake: drawLaptopWithSunBehind()
            case .lid: drawClosedLaptopWithSun()
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    /// SF Symbol moon, centred on the same 20x18 canvas as the other icons so the status item never changes width.
    private static func drawMoonStars() {
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let sym = NSImage(systemSymbolName: "moon.stars", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
        let size = sym.size
        sym.draw(in: NSRect(x: (20 - size.width) / 2, y: (18 - size.height) / 2, width: size.width, height: size.height))
    }

    private static func drawSun(center c: NSPoint, radius r: CGFloat, rayFrom: CGFloat, rayTo: CGFloat, skipping skip: Set<Int> = []) {
        NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
        let rays = NSBezierPath()
        rays.lineWidth = 1.4
        rays.lineCapStyle = .round
        for i in 0..<8 where !skip.contains(i) {
            let a = CGFloat(i) * .pi / 4
            rays.move(to: NSPoint(x: c.x + cos(a) * rayFrom, y: c.y + sin(a) * rayFrom))
            rays.line(to: NSPoint(x: c.x + cos(a) * rayTo, y: c.y + sin(a) * rayTo))
        }
        rays.stroke()
    }

    private static func drawLaptopWithSunBehind() {
        drawSun(center: NSPoint(x: 13.6, y: 12.2), radius: 2.6, rayFrom: 3.9, rayTo: 5.0)
        let screen = NSRect(x: 1.6, y: 5.6, width: 12.2, height: 8)
        let base = NSRect(x: 0.4, y: 2.4, width: 15.4, height: 2.4)
        // knock out a gap around the laptop so the sun reads as "behind" it
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            NSBezierPath(roundedRect: screen.insetBy(dx: -1.3, dy: -1.3), xRadius: 2.8, yRadius: 2.8).fill()
            NSBezierPath(roundedRect: base.insetBy(dx: -1.3, dy: -1.3), xRadius: 2.4, yRadius: 2.4).fill()
            ctx.restoreGState()
        }
        NSBezierPath(roundedRect: screen, xRadius: 1.6, yRadius: 1.6).fill()
        NSBezierPath(roundedRect: base, xRadius: 1.2, yRadius: 1.2).fill()
    }

    private static func drawClosedLaptopWithSun() {
        // Closed laptop seen from slightly above: lid top face in perspective, thin front edge, logo cut-out.
        let face = NSBezierPath()
        face.move(to: NSPoint(x: 3.6, y: 9.0))
        face.line(to: NSPoint(x: 16.4, y: 9.0))
        face.line(to: NSPoint(x: 19.4, y: 3.9))
        face.line(to: NSPoint(x: 0.6, y: 3.9))
        face.close()
        face.lineJoinStyle = .round
        face.lineWidth = 1.2
        face.fill()
        face.stroke()
        NSBezierPath(roundedRect: NSRect(x: 0.6, y: 1.5, width: 18.8, height: 1.7), xRadius: 0.85, yRadius: 0.85).fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            NSBezierPath(ovalIn: NSRect(x: 8.4, y: 5.1, width: 3.2, height: 3.2)).fill()
            ctx.restoreGState()
        }
        drawSun(center: NSPoint(x: 10, y: 12.4), radius: 2.3, rayFrom: 3.7, rayTo: 4.9, skipping: [5, 6, 7])
    }
}
