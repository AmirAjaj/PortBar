#!/usr/bin/env swift
//
// Generates PortBar's artwork from code (no design tool needed):
//   • Resources/AppIcon.icns           — the app icon (bundled into the .app)
//   • Resources/MenuBarIcon@1x/2x.png  — brand asset (menu bar renders the
//                                         same plug live from the SF Symbol)
//
// Run from the repo root:  swift Scripts/make-icons.swift
//
import AppKit

let root = FileManager.default.currentDirectoryPath

// MARK: - Drawing helpers

/// Renders into an RGBA bitmap of the given pixel size using a CG drawing block.
func bitmap(size: Int, _ draw: (CGContext, CGFloat) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext, CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// An SF Symbol tinted to a solid color, as an NSImage.
func symbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        .withSymbolConfiguration(cfg)!
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// MARK: - App icon

func drawAppIcon(_ ctx: CGContext, _ s: CGFloat) {
    let inset = s * 0.085
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237 // macOS squircle-ish corner
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 1).cgColor,
                                   NSColor(srgbRed: 0.40, green: 0.36, blue: 0.95, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    ctx.restoreGState()

    let glyph = symbol("powerplug.fill", pointSize: s * 0.46, color: .white)
    let gs = glyph.size
    glyph.draw(in: CGRect(x: (s - gs.width) / 2, y: (s - gs.height) / 2, width: gs.width, height: gs.height))
}

// Build the .iconset then convert to .icns
let iconset = root + "/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (px, name) in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
                   (128, "128x128"), (256, "128x128@2x"), (256, "256x256"),
                   (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")] {
    writePNG(bitmap(size: px, drawAppIcon), to: "\(iconset)/icon_\(name).png")
}
try! FileManager.default.createDirectory(atPath: root + "/Resources", withIntermediateDirectories: true)
let icnsTask = Process()
icnsTask.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
icnsTask.arguments = ["-c", "icns", iconset, "-o", root + "/Resources/AppIcon.icns"]
try! icnsTask.run(); icnsTask.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconset)

// MARK: - Menu-bar glyph (template: solid black + alpha, isTemplate set at load)

func drawMenuGlyph(_ ctx: CGContext, _ s: CGFloat) {
    let glyph = symbol("powerplug.fill", pointSize: s * 0.82, color: .black)
    let gs = glyph.size
    glyph.draw(in: CGRect(x: (s - gs.width) / 2, y: (s - gs.height) / 2, width: gs.width, height: gs.height))
}
let resDir = root + "/Resources"
writePNG(bitmap(size: 18, drawMenuGlyph), to: "\(resDir)/MenuBarIcon.png")
writePNG(bitmap(size: 36, drawMenuGlyph), to: "\(resDir)/MenuBarIcon@2x.png")

print("✅ Wrote Resources/AppIcon.icns and Resources/MenuBarIcon{,@2x}.png")
