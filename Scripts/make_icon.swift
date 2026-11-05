#!/usr/bin/env swift
// Renders the app icon (1024x1024 PNG) and builds Resources/AppIcon.icns.
import AppKit

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let nsctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = nsctx
let ctx = nsctx.cgContext

// macOS icon body: 824pt squircle centred in 1024
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 188, yRadius: 188)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x000000, 0.22).cgColor)
color(0x4A9DFA).setFill()
bodyPath.fill()
ctx.restoreGState()

// Background gradient
ctx.saveGState()
bodyPath.addClip()
NSGradient(colors: [color(0x6CC4FF), color(0x57AEFF), color(0x4A9DFA)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: body, angle: -90)

// very subtle top light
NSGradient(colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)])!.draw(in: body, angle: -90)
ctx.restoreGState()

// --- Line-art sun emerging from a frosted-glass laptop ---
ctx.saveGState()
ctx.translateBy(x: 0, y: -55)

let lid = NSRect(x: 292, y: 318, width: 440, height: 270)
let base = NSRect(x: 232, y: 270, width: 560, height: 42)
let sunCenter = NSPoint(x: 512, y: 648)
let sunColor = color(0xFFD84D)

func strokeSun() {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 16, color: color(0xF59E0B, 0.35).cgColor)
    sunColor.setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: sunCenter.x - 120, y: sunCenter.y - 120, width: 240, height: 240))
    ring.lineWidth = 36
    ring.stroke()
    let rays = NSBezierPath()
    rays.lineWidth = 36
    rays.lineCapStyle = .round
    for deg in stride(from: 0.0, through: 180.0, by: 30.0) {
        let a = CGFloat(deg) * .pi / 180
        let outer: CGFloat = sin(a) < -0.9 ? 238 : 246   // keep the bottom ray inside the lid
        rays.move(to: NSPoint(x: sunCenter.x + cos(a) * 186, y: sunCenter.y + sin(a) * 186))
        rays.line(to: NSPoint(x: sunCenter.x + cos(a) * outer, y: sunCenter.y + sin(a) * outer))
    }
    rays.stroke()
    ctx.restoreGState()
}

let bgGradient = NSGradient(colors: [color(0x6CC4FF), color(0x57AEFF), color(0x4A9DFA)],
                            atLocations: [0, 0.55, 1], colorSpace: .sRGB)!

/// Opaque laptop part that really hides the sun behind it. A thin ring of background colour around it
/// cuts the sun cleanly where it passes behind.
func solidPart(_ rect: NSRect, radius: CGFloat, top: UInt32, bottom: UInt32) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    // gap ring in background colour
    ctx.saveGState()
    let gap = NSBezierPath(roundedRect: rect.insetBy(dx: -12, dy: -12), xRadius: radius + 12, yRadius: radius + 12)
    gap.addClip()
    bgGradient.draw(in: body, angle: -90)
    ctx.restoreGState()
    // soft shadow + body
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x0B1E5A, 0.25).cgColor)
    color(top).setFill(); path.fill()
    ctx.restoreGState()
    ctx.saveGState()
    path.addClip()
    NSGradient(starting: color(top), ending: color(bottom))!.draw(in: rect, angle: -90)
    ctx.restoreGState()
    color(0xFFFFFF, 0.8).setStroke()
    path.lineWidth = 2.5
    path.stroke()
}

// sun first, then the laptop in front of it
strokeSun()
solidPart(lid, radius: 44, top: 0xF4F9FF, bottom: 0xBFD7FF)
let screen = lid.insetBy(dx: 26, dy: 26)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 22, yRadius: 22)
ctx.saveGState()
screenPath.addClip()
NSGradient(colors: [color(0x3F78E8), color(0x1F45B5)])!.draw(in: screen, angle: -90)
// faint reflection so the screen still feels like glass
NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!
    .draw(in: NSRect(x: screen.minX, y: screen.midY, width: screen.width, height: screen.height / 2), angle: -90)
ctx.restoreGState()
solidPart(base, radius: 21, top: 0xE6F0FF, bottom: 0xA9C6F5)
color(0xFFFFFF, 0.6).setFill()
NSBezierPath(roundedRect: NSRect(x: 462, y: 285, width: 100, height: 9), xRadius: 4.5, yRadius: 4.5).fill()

ctx.restoreGState()

// Edge highlight on the body
color(0xFFFFFF, 0.18).setStroke()
let edge = NSBezierPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), xRadius: 186, yRadius: 186)
edge.lineWidth = 3
edge.stroke()

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
let pngPath = "\(outDir)/AppIcon-1024.png"
try! png.write(to: URL(fileURLWithPath: pngPath))

// iconset -> icns
let iconset = "\(outDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let sizes: [(Int, String)] = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
                              (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"),
                              (512, "512x512"), (1024, "512x512@2x")]
for (px, name) in sizes {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    p.arguments = ["-z", "\(px)", "\(px)", pngPath, "--out", "\(iconset)/icon_\(name).png"]
    p.standardOutput = FileHandle.nullDevice
    try! p.run(); p.waitUntilExit()
}
let ic = Process()
ic.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
ic.arguments = ["-c", "icns", iconset, "-o", "\(outDir)/AppIcon.icns"]
try! ic.run(); ic.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconset)
print("Wrote \(outDir)/AppIcon.icns")
