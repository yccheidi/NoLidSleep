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
color(0x1D4ED8).setFill()
bodyPath.fill()
ctx.restoreGState()

// Background gradient
ctx.saveGState()
bodyPath.addClip()
NSGradient(colors: [color(0x4DB8FF), color(0x2B7BF0), color(0x1D4ED8)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: body, angle: -90)

// very subtle top light
NSGradient(colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)])!.draw(in: body, angle: -90)
ctx.restoreGState()

// --- Line-art sun emerging from a frosted-glass laptop ---
ctx.saveGState()
ctx.translateBy(x: 0, y: -45)

let lid = NSRect(x: 292, y: 318, width: 440, height: 270)
let base = NSRect(x: 232, y: 270, width: 560, height: 42)
let sunCenter = NSPoint(x: 512, y: 588)
let sunColor = color(0xFFD84D)

func strokeSun() {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 16, color: color(0xF59E0B, 0.35).cgColor)
    sunColor.setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: sunCenter.x - 128, y: sunCenter.y - 128, width: 256, height: 256))
    ring.lineWidth = 36
    ring.stroke()
    let rays = NSBezierPath()
    rays.lineWidth = 36
    rays.lineCapStyle = .round
    for deg in stride(from: 30.0, through: 150.0, by: 30.0) {
        let a = CGFloat(deg) * .pi / 180
        rays.move(to: NSPoint(x: sunCenter.x + cos(a) * 198, y: sunCenter.y + sin(a) * 198))
        rays.line(to: NSPoint(x: sunCenter.x + cos(a) * 262, y: sunCenter.y + sin(a) * 262))
    }
    rays.stroke()
    ctx.restoreGState()
}

func frostedGlass(_ rect: NSRect, radius: CGFloat, topAlpha: CGFloat, bottomAlpha: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x0B1E5A, 0.22).cgColor)
    color(0xFFFFFF, 0.2).setFill(); path.fill()
    ctx.restoreGState()
    ctx.saveGState()
    path.addClip()
    NSGradient(starting: color(0xFFFFFF, topAlpha), ending: color(0xFFFFFF, bottomAlpha))!.draw(in: rect, angle: -90)
    ctx.restoreGState()
    color(0xFFFFFF, 0.55).setStroke()
    path.lineWidth = 2.5
    path.stroke()
}

// sun behind the glass
strokeSun()
// lid + screen
frostedGlass(lid, radius: 44, topAlpha: 0.72, bottomAlpha: 0.42)
let screen = lid.insetBy(dx: 26, dy: 26)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 22, yRadius: 22)
ctx.saveGState()
screenPath.addClip()
NSGradient(colors: [color(0x1E40AF, 0.22), color(0x1E3A8A, 0.38)])!.draw(in: screen, angle: -90)
ctx.restoreGState()
// let the sun glow through the glass so it doesn't look muddy
ctx.saveGState()
NSBezierPath(roundedRect: lid, xRadius: 44, yRadius: 44).addClip()
ctx.setAlpha(0.55)
strokeSun()
ctx.restoreGState()
// base
frostedGlass(base, radius: 21, topAlpha: 0.78, bottomAlpha: 0.55)
color(0xFFFFFF, 0.45).setFill()
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
