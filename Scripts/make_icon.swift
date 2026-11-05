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

// Colour themes (weather-app style). Usage: make_icon.swift <outDir> [graphite (default)|black|charcoal|gray|lavender|peach]
struct Theme {
    let bg: [UInt32]; let screen: [UInt32]; let frame: [UInt32]; let base: [UInt32]; let sun: UInt32; let glow: UInt32
}
let themes: [String: Theme] = [
    "gray": Theme(bg: [0xF4F5F7, 0xE4E7EC, 0xD5D9E0], screen: [0xCFD5DF, 0xAEB6C6],
                  frame: [0xFFFFFF, 0xEEF0F4], base: [0xFAFBFC, 0xDDE1E8], sun: 0xFFC83D, glow: 0xF59E0B),
    "lavender": Theme(bg: [0xEFEAFF, 0xDDD3FB, 0xCBBFF3], screen: [0xC6BBF2, 0xA394E2],
                      frame: [0xFFFFFF, 0xF0ECFF], base: [0xFBF9FF, 0xDCD4F5], sun: 0xFFC83D, glow: 0xF59E0B),
    "charcoal": Theme(bg: [0x4A4E57, 0x3A3D45, 0x2B2E35], screen: [0x5A606C, 0x383C46],
                      frame: [0xF3F4F6, 0xB9BDC6], base: [0xDEE0E5, 0x8E939E], sun: 0xFFC83D, glow: 0xF59E0B),
    "graphite": Theme(bg: [0x37393F, 0x25272B, 0x15161A], screen: [0x474B53, 0x25272D],
                      frame: [0xFFFFFF, 0xE3E5EA], base: [0xF3F4F7, 0xC3C6CD], sun: 0xFFC83D, glow: 0xF59E0B),
    "black": Theme(bg: [0x26262A, 0x151518, 0x08080A], screen: [0x34343A, 0x17171B],
                   frame: [0xE9EAEC, 0x9A9DA5], base: [0xC9CBD0, 0x6E7178], sun: 0xFFC83D, glow: 0xF59E0B),
    "peach": Theme(bg: [0xFFEBDA, 0xFFD7B9, 0xFFC29C], screen: [0xFFC39A, 0xF79F6C],
                   frame: [0xFFFFFF, 0xFFF1E6], base: [0xFFFAF5, 0xFBDCC4], sun: 0xFFFFFF, glow: 0xFF8A3D),
]
let themeName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "graphite"
let theme = themes[themeName] ?? themes["graphite"]!
let bgGradient = NSGradient(colors: theme.bg.map { color($0) }, atLocations: [0, 0.55, 1], colorSpace: .sRGB)!

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
color(theme.bg[2]).setFill()
bodyPath.fill()
ctx.restoreGState()

// Background gradient
ctx.saveGState()
bodyPath.addClip()
bgGradient.draw(in: body, angle: -90)

// very subtle top light
NSGradient(colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)])!.draw(in: body, angle: -90)
ctx.restoreGState()

// --- Line-art sun emerging from a frosted-glass laptop ---
ctx.saveGState()
ctx.translateBy(x: 0, y: -55)

let lid = NSRect(x: 292, y: 318, width: 440, height: 270)
let base = NSRect(x: 232, y: 268, width: 560, height: 44)
let sunCenter = NSPoint(x: 512, y: 648)
let sunColor = color(theme.sun)

func strokeSun() {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 16, color: color(theme.glow, 0.35).cgColor)
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
    // brushed-metal feel: specular band on top, darker lip at the bottom
    NSGradient(colors: [color(0xFFFFFF, 0.65), color(0xFFFFFF, 0)])!
        .draw(in: NSRect(x: rect.minX, y: rect.maxY - rect.height * 0.35, width: rect.width, height: rect.height * 0.35), angle: -90)
    NSGradient(colors: [color(0x000000, 0), color(0x1B1F2A, 0.28)])!
        .draw(in: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.3), angle: -90)
    ctx.restoreGState()
    color(0xFFFFFF, 0.9).setStroke()
    path.lineWidth = 2.5
    path.stroke()
}

// sun first, then the laptop in front of it
strokeSun()
solidPart(lid, radius: 44, top: theme.frame[0], bottom: theme.frame[1])
let screen = lid.insetBy(dx: 26, dy: 26)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 22, yRadius: 22)
ctx.saveGState()
screenPath.addClip()
NSGradient(colors: theme.screen.map { color($0) })!.draw(in: screen, angle: -90)
// faint reflection so the screen still feels like glass
NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!
    .draw(in: NSRect(x: screen.minX, y: screen.midY, width: screen.width, height: screen.height / 2), angle: -90)
ctx.restoreGState()
// bezel: inner edge and camera, so it clearly reads as a laptop
color(0x000000, 0.38).setStroke()
screenPath.lineWidth = 3
screenPath.stroke()
color(0x2A2D36, 0.6).setFill()
NSBezierPath(ovalIn: NSRect(x: lid.midX - 6, y: lid.maxY - 20, width: 12, height: 12)).fill()

solidPart(base, radius: 22, top: theme.base[0], bottom: theme.base[1])
// thumb notch on the front edge of the base
ctx.saveGState()
NSBezierPath(roundedRect: base, xRadius: 22, yRadius: 22).addClip()
let notch = NSBezierPath(roundedRect: NSRect(x: base.midX - 56, y: base.maxY - 17, width: 112, height: 40), xRadius: 16, yRadius: 16)
NSGradient(colors: [color(0x6C707A, 0.9), color(0xB4B8C1, 0.9)])!.draw(in: notch, angle: -90)
ctx.restoreGState()

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
