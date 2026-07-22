#!/usr/bin/env swift

import AppKit
import Foundation

private struct IconVariant {
  let filename: String
  let pixels: Int
}

private let variants = [
  IconVariant(filename: "icon_16x16.png", pixels: 16),
  IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
  IconVariant(filename: "icon_32x32.png", pixels: 32),
  IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
  IconVariant(filename: "icon_128x128.png", pixels: 128),
  IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
  IconVariant(filename: "icon_256x256.png", pixels: 256),
  IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
  IconVariant(filename: "icon_512x512.png", pixels: 512),
  IconVariant(filename: "icon_512x512@2x.png", pixels: 1024),
]

private func renderIcon(pixels: Int) throws -> Data {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    throw NSError(domain: "TideIconGenerator", code: 1)
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  defer { NSGraphicsContext.restoreGraphicsState() }

  let size = CGFloat(pixels)
  let canvas = NSRect(x: 0, y: 0, width: size, height: size)
  NSColor.clear.setFill()
  canvas.fill()

  let inset = size * 0.064
  let iconRect = canvas.insetBy(dx: inset, dy: inset)
  let cornerRadius = size * 0.215
  let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

  NSGraphicsContext.current?.cgContext.setShadow(
    offset: CGSize(width: 0, height: -size * 0.028),
    blur: size * 0.055,
    color: NSColor.black.withAlphaComponent(0.2).cgColor
  )
  let gradient = NSGradient(
    starting: NSColor(red: 0.43, green: 0.78, blue: 1, alpha: 1),
    ending: NSColor(red: 0.18, green: 0.53, blue: 0.96, alpha: 1)
  )!
  gradient.draw(in: iconPath, angle: -90)
  NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

  let glowRect = NSRect(
    x: iconRect.minX + iconRect.width * 0.08,
    y: iconRect.midY,
    width: iconRect.width * 0.84,
    height: iconRect.height * 0.58
  )
  let glow = NSGradient(
    starting: NSColor.white.withAlphaComponent(0.2),
    ending: NSColor.white.withAlphaComponent(0)
  )!
  NSGraphicsContext.saveGraphicsState()
  iconPath.addClip()
  glow.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: .zero)
  NSGraphicsContext.restoreGraphicsState()

  NSColor.white.withAlphaComponent(0.42).setStroke()
  iconPath.lineWidth = max(0.75, size * 0.006)
  iconPath.stroke()

  let glyphLeft = size * 0.255
  let glyphRight = size * 0.745
  let glyphWidth = glyphRight - glyphLeft
  let waveAmplitude = size * 0.052

  func drawWave(centerY: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: glyphLeft, y: centerY))
    path.curve(
      to: NSPoint(x: glyphLeft + glyphWidth / 2, y: centerY),
      controlPoint1: NSPoint(x: glyphLeft + glyphWidth * 0.14, y: centerY + waveAmplitude),
      controlPoint2: NSPoint(x: glyphLeft + glyphWidth * 0.36, y: centerY - waveAmplitude)
    )
    path.curve(
      to: NSPoint(x: glyphRight, y: centerY),
      controlPoint1: NSPoint(x: glyphLeft + glyphWidth * 0.64, y: centerY + waveAmplitude),
      controlPoint2: NSPoint(x: glyphLeft + glyphWidth * 0.86, y: centerY - waveAmplitude)
    )
    path.lineWidth = max(1.35, size * 0.048)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.98).setStroke()
    path.stroke()
  }

  drawWave(centerY: size * 0.49)
  drawWave(centerY: size * 0.365)

  let dotDiameter = max(2, size * 0.074)
  let dotRect = NSRect(
    x: size * 0.64,
    y: size * 0.65,
    width: dotDiameter,
    height: dotDiameter
  )
  NSColor.white.withAlphaComponent(0.98).setFill()
  NSBezierPath(ovalIn: dotRect).fill()

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "TideIconGenerator", code: 2)
  }
  return data
}

private func renderGlyph(pixels: Int, color: NSColor) throws -> Data {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    throw NSError(domain: "TideIconGenerator", code: 3)
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  defer { NSGraphicsContext.restoreGraphicsState() }

  let size = CGFloat(pixels)
  let canvas = NSRect(x: 0, y: 0, width: size, height: size)
  NSColor.clear.setFill()
  canvas.fill()

  let glyphLeft = size * 0.255
  let glyphRight = size * 0.745
  let glyphWidth = glyphRight - glyphLeft
  let waveAmplitude = size * 0.052

  func drawWave(centerY: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: glyphLeft, y: centerY))
    path.curve(
      to: NSPoint(x: glyphLeft + glyphWidth / 2, y: centerY),
      controlPoint1: NSPoint(x: glyphLeft + glyphWidth * 0.14, y: centerY + waveAmplitude),
      controlPoint2: NSPoint(x: glyphLeft + glyphWidth * 0.36, y: centerY - waveAmplitude)
    )
    path.curve(
      to: NSPoint(x: glyphRight, y: centerY),
      controlPoint1: NSPoint(x: glyphLeft + glyphWidth * 0.64, y: centerY + waveAmplitude),
      controlPoint2: NSPoint(x: glyphLeft + glyphWidth * 0.86, y: centerY - waveAmplitude)
    )
    path.lineWidth = max(1.35, size * 0.048)
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
  }

  drawWave(centerY: size * 0.49)
  drawWave(centerY: size * 0.365)

  let dotDiameter = max(2, size * 0.074)
  let dotRect = NSRect(
    x: size * 0.64,
    y: size * 0.65,
    width: dotDiameter,
    height: dotDiameter
  )
  color.setFill()
  NSBezierPath(ovalIn: dotRect).fill()

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "TideIconGenerator", code: 4)
  }
  return data
}

let outputDirectory = URL(
  fileURLWithPath: CommandLine.arguments.dropFirst().first
    ?? "Tide/Assets.xcassets/AppIcon.appiconset",
  isDirectory: true
)
let icnsOutputURL = URL(
  fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first
    ?? "Tide/Resources/TideAppIcon.icns"
)
let iconComposerDirectory = URL(
  fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().dropFirst().first
    ?? "Tide/AppIcon.icon",
  isDirectory: true
)
let iconComposerAssetsDirectory = iconComposerDirectory.appendingPathComponent(
  "Assets",
  isDirectory: true
)
let temporaryIconset = FileManager.default.temporaryDirectory
  .appendingPathComponent("Tide-\(UUID().uuidString)")
  .appendingPathExtension("iconset")

try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
  at: icnsOutputURL.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
  at: temporaryIconset,
  withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
  at: iconComposerAssetsDirectory,
  withIntermediateDirectories: true
)
defer { try? FileManager.default.removeItem(at: temporaryIconset) }

for variant in variants {
  let data = try renderIcon(pixels: variant.pixels)
  try data.write(to: outputDirectory.appendingPathComponent(variant.filename), options: .atomic)
  try data.write(to: temporaryIconset.appendingPathComponent(variant.filename), options: .atomic)
}

let lightGlyphOutputURL = iconComposerAssetsDirectory.appendingPathComponent("TideGlyph.png")
let darkGlyphOutputURL = iconComposerAssetsDirectory.appendingPathComponent("TideGlyphDark.png")
let lightGlyphData = try renderGlyph(
  pixels: 1024,
  color: NSColor.white.withAlphaComponent(0.98)
)
let darkGlyphData = try renderGlyph(
  pixels: 1024,
  color: NSColor(red: 0.45, green: 0.65, blue: 0.86, alpha: 0.94)
)
try lightGlyphData.write(to: lightGlyphOutputURL, options: .atomic)
try darkGlyphData.write(to: darkGlyphOutputURL, options: .atomic)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
  "-c", "icns",
  temporaryIconset.path,
  "-o", icnsOutputURL.path,
]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
  throw NSError(
    domain: "TideIconGenerator",
    code: Int(iconutil.terminationStatus),
    userInfo: [NSLocalizedDescriptionKey: "iconutil failed to create TideAppIcon.icns"]
  )
}

print(
  "Generated \(variants.count) legacy app icon PNGs, \(icnsOutputURL.path), "
    + "and light/dark Icon Composer glyphs"
)
