#!/usr/bin/env swift
//
// Generates docs/social-preview.png — the 1280×640 banner GitHub shows when the
// repo link is shared. Run from the repo root:  swift Scripts/make-social.swift
//
import AppKit

let root = FileManager.default.currentDirectoryPath
let width = 1280
let height = 640

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

// Background: deep gradient in the brand's blue/indigo family.
let bg = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(srgbRed: 0.07, green: 0.09, blue: 0.20, alpha: 1).cgColor,
        NSColor(srgbRed: 0.10, green: 0.12, blue: 0.32, alpha: 1).cgColor,
    ] as CFArray,
    locations: [0, 1])!
cg.drawLinearGradient(
    bg, start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: CGFloat(width), y: 0), options: [])

// App icon on the left.
let iconSize: CGFloat = 320
if let icon = NSImage(contentsOfFile: root + "/Resources/AppIcon.png") {
    icon.draw(in: CGRect(x: 110, y: (CGFloat(height) - iconSize) / 2, width: iconSize, height: iconSize))
}

// Text block on the right.
let textX: CGFloat = 500
let title = NSAttributedString(
    string: "PortBar",
    attributes: [
        .font: NSFont.systemFont(ofSize: 130, weight: .bold),
        .foregroundColor: NSColor.white,
    ])
title.draw(at: CGPoint(x: textX, y: 360))

let tagline = NSAttributedString(
    string: "See what's running on your ports —\nand kill it — from the menu bar.",
    attributes: [
        .font: NSFont.systemFont(ofSize: 40, weight: .regular),
        .foregroundColor: NSColor(white: 0.78, alpha: 1),
    ])
tagline.draw(in: CGRect(x: textX + 4, y: 170, width: 660, height: 160))

NSGraphicsContext.restoreGraphicsState()

let outDir = root + "/docs"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: outDir + "/social-preview.png"))
print("✅ Wrote docs/social-preview.png (\(width)x\(height))")
