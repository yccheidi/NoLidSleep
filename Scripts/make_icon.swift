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
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0x000000, 0.35).cgColor)
color(0x1B2250).setFill()
bodyPath.fill()
ctx.restoreGState()

// Background gradient
ctx.saveGState()
bodyPath.addClip()
NSGradient(colors: [color(0x6E8CFF), color(0x4B4FE0), color(0x211B66)],
           atLocations: [0, 0.5, 1], colorSpace: .sRGB)!.draw(in: body, angle: -90)

// Soft light bloom behind the laptop
NSGradient(colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)])!
    .draw(fromCenter: NSPoint(x: 512, y: 560), radius: 0, toCenter: NSPoint(x: 512, y: 560), radius: 380, options: [])

// Glass sheen on the upper half
let sheen = NSBezierPath(ovalIn: NSRect(x: -100, y: 520, width: 1224, height: 900))
ctx.saveGState()
sheen.addClip()
NSGradient(colors: [color(0xFFFFFF, 0.30), color(0xFFFFFF, 0.04)])!.draw(in: body, angle: -90)
ctx.restoreGState()
ctx.restoreGState()

// Laptop (front view, lid open)
ctx.translateBy(x: 0, y: -75)
func glass(_ rect: NSRect, radius: CGFloat, top: CGFloat, bottom: CGFloat) {
    let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x0B0E3A, 0.45).cgColor)
    color(0xFFFFFF, 0.5).setFill(); p.fill()
    ctx.restoreGState()
    ctx.saveGState()
    p.addClip()
    NSGradient(starting: color(0xFFFFFF, top), ending: color(0xFFFFFF, bottom))!.draw(in: rect, angle: -90)
    ctx.restoreGState()
    color(0xFFFFFF, 0.65).setStroke()
    p.lineWidth = 3
    p.stroke()
}

let lid = NSRect(x: 292, y: 468, width: 440, height: 290)
glass(lid, radius: 40, top: 0.95, bottom: 0.70)

// Screen
let screen = lid.insetBy(dx: 26, dy: 26)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 20, yRadius: 20)
ctx.saveGState()
screenPath.addClip()
NSGradient(colors: [color(0x1B2060), color(0x0E1037)])!.draw(in: screen, angle: -90)
// glowing "awake" orb
let c = NSPoint(x: screen.midX, y: screen.midY)
NSGradient(colors: [color(0xFFE29A, 0.95), color(0xFFB347, 0.55), color(0xFF8A3D, 0)],
           atLocations: [0, 0.35, 1], colorSpace: .sRGB)!
    .draw(fromCenter: c, radius: 0, toCenter: c, radius: 120, options: [])
color(0xFFF3D1).setFill()
NSBezierPath(ovalIn: NSRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68)).fill()
ctx.restoreGState()

// Base
let base = NSRect(x: 232, y: 424, width: 560, height: 46)
glass(base, radius: 23, top: 0.92, bottom: 0.62)
// Notch on the base
color(0x1B2060, 0.35).setFill()
NSBezierPath(roundedRect: NSRect(x: 452, y: 444, width: 120, height: 10), xRadius: 5, yRadius: 5).fill()

// Edge highlight on the body
color(0xFFFFFF, 0.35).setStroke()
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
