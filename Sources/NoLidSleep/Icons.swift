import AppKit

/// Menu bar template icons, one per mode:
///  off   - crescent moon with sparkles
///  awake - open laptop with a sun behind it
///  lid   - closed laptop with a sun above it
enum Icons {
    static func image(for mode: Mode) -> NSImage {
        // Drawn on a 20x18 grid, shown at 85% so the status item can be narrow.
        let scale: CGFloat = 0.85
        let img = NSImage(size: NSSize(width: 20 * scale, height: 18 * scale), flipped: false) { _ in
            NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
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

    /// Solid crescent moon with two sparkles, drawn to fill the whole 20x18 canvas.
    private static func drawMoonStars() {
        NSBezierPath(ovalIn: NSRect(x: 0.2, y: 1.0, width: 16.4, height: 16.4)).fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            NSBezierPath(ovalIn: NSRect(x: 5.0, y: 3.8, width: 14.0, height: 14.0)).fill()
            ctx.restoreGState()
        }
        sparkle(center: NSPoint(x: 14.6, y: 10.6), radius: 3.4)
        sparkle(center: NSPoint(x: 10.0, y: 14.8), radius: 2.0)
    }

    /// Four-pointed star.
    private static func sparkle(center c: NSPoint, radius r: CGFloat) {
        let k = r * 0.28
        let p = NSBezierPath()
        p.move(to: NSPoint(x: c.x, y: c.y + r))
        p.curve(to: NSPoint(x: c.x + r, y: c.y), controlPoint1: NSPoint(x: c.x + k, y: c.y + k), controlPoint2: NSPoint(x: c.x + k, y: c.y + k))
        p.curve(to: NSPoint(x: c.x, y: c.y - r), controlPoint1: NSPoint(x: c.x + k, y: c.y - k), controlPoint2: NSPoint(x: c.x + k, y: c.y - k))
        p.curve(to: NSPoint(x: c.x - r, y: c.y), controlPoint1: NSPoint(x: c.x - k, y: c.y - k), controlPoint2: NSPoint(x: c.x - k, y: c.y - k))
        p.curve(to: NSPoint(x: c.x, y: c.y + r), controlPoint1: NSPoint(x: c.x - k, y: c.y + k), controlPoint2: NSPoint(x: c.x - k, y: c.y + k))
        p.close()
        p.fill()
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
        drawSun(center: NSPoint(x: 14.7, y: 12.6), radius: 2.3, rayFrom: 3.6, rayTo: 4.6, skipping: [4, 5, 6, 7])
        let screen = NSRect(x: 0.6, y: 5.0, width: 12.8, height: 8.6)
        let base = NSRect(x: 0.0, y: 1.6, width: 14.6, height: 2.6)
        // knock out a gap around the laptop so the sun reads as "behind" it
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            NSBezierPath(roundedRect: screen.insetBy(dx: -1.2, dy: -1.2), xRadius: 2.8, yRadius: 2.8).fill()
            NSBezierPath(roundedRect: base.insetBy(dx: -1.2, dy: -1.2), xRadius: 2.4, yRadius: 2.4).fill()
            ctx.restoreGState()
        }
        NSBezierPath(roundedRect: screen, xRadius: 1.8, yRadius: 1.8).fill()
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
