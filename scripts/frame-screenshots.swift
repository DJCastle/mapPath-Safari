#!/usr/bin/swift
//
// frame-screenshots.swift — turn raw simulator captures into App Store
// screenshots: brand gradient background, headline + subline, and the
// capture inside a rounded device frame with a soft shadow.
//
// Usage:
//     swift scripts/frame-screenshots.swift <spec.json> [--apply]
//
// Dry-run by default: prints what it would render and checks every input
// exists. --apply writes the PNGs. Output is opaque RGB (no alpha channel —
// App Store Connect rejects PNGs with one) at exactly the size the spec
// names, so the result uploads into the matching device slot unchanged.
//
// The spec is a JSON object:
//
//   {
//     "outputDir": "screenshots",
//     "sets": [
//       {
//         "name": "iphone",          // used in log lines only
//         "width": 1320, "height": 2868,
//         "cornerRadius": 150,      // of the device screen, in output px
//         "items": [
//           { "input": "/tmp/mp-shots/pm-welcome.png",
//             "output": "iphone-1.png",
//             "headline": "Map links. Apple Maps.",
//             "subline": "Google, Waze, Bing and HERE links open in Apple Maps." }
//         ]
//       }
//     ]
//   }
//
// Each input must already be the set's width × height (a straight device
// capture); it is scaled down to fit under the headline, never cropped.
//
// A set may add "layout": "landscape" for the Mac App Store (2880×1800):
// the text block sits on the left third and the capture — a window
// screenshot of any size, not a full screen — is scaled to fit the right
// two thirds inside a window-style rounded frame with a shadow. Landscape
// inputs are not size-checked, since Mac windows vary.
//

import Foundation
import AppKit
import CoreGraphics

// MARK: - Spec

/// Optional magnified inset for landscape shots: a region of the capture,
/// given as fractions of its width/height (origin top-left), redrawn larger
/// under the headline so small UI — Safari's status-bar URL — is legible.
struct Callout: Decodable {
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    let scale: CGFloat
}

struct Item: Decodable {
    let input: String
    let output: String
    let headline: String
    let subline: String?
    let callout: Callout?
}

struct ScreenSet: Decodable {
    let name: String
    let width: Int
    let height: Int
    let cornerRadius: CGFloat
    let layout: String?
    let items: [Item]

    var isLandscape: Bool { layout == "landscape" }
}

struct Spec: Decodable {
    let outputDir: String
    let sets: [ScreenSet]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fail("Usage: frame-screenshots.swift <spec.json> [--apply]")
}
let specPath = args[1]
let apply = args.contains("--apply")

guard let specData = FileManager.default.contents(atPath: specPath) else {
    fail("Cannot read spec: \(specPath)")
}
let spec: Spec
do {
    spec = try JSONDecoder().decode(Spec.self, from: specData)
} catch {
    fail("Spec is not valid: \(error)")
}

// Paths in the spec are relative to the spec file's directory unless absolute.
let specDir = URL(fileURLWithPath: specPath).deletingLastPathComponent()
func resolve(_ path: String) -> URL {
    path.hasPrefix("/") ? URL(fileURLWithPath: path) : specDir.appendingPathComponent(path)
}
let outputDir = resolve(spec.outputDir)

// MARK: - Brand

// Same template as ContactTap's App Store set (compose.swift there), but
// in Map Path's own palette, which is the popup's: Apple Maps' cream
// "paper" background, near-black ink, the warm grey it uses for secondary
// text, and a blue→green accent — system blue for the route, directions
// green for the pin — used as a thin rule under the headline, exactly like
// the popup's header bar. Saturated full-bleed colour is ContactTap's
// look, not this app's.
let paperTop   = CGColor(red: 0xf8/255, green: 0xf5/255, blue: 0xee/255, alpha: 1)
let paperBottom = CGColor(red: 0xea/255, green: 0xe4/255, blue: 0xd6/255, alpha: 1)
let ink        = NSColor(red: 0x1c/255, green: 0x1c/255, blue: 0x1e/255, alpha: 1)
let inkMuted   = NSColor(red: 0x7a/255, green: 0x76/255, blue: 0x6c/255, alpha: 1)
let brandBlue  = CGColor(red: 0x0a/255, green: 0x84/255, blue: 0xff/255, alpha: 1)
let brandGreen = CGColor(red: 0x34/255, green: 0xc7/255, blue: 0x59/255, alpha: 1)
let bezel      = CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)

func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let desc = base.fontDescriptor.withDesign(.rounded),
          let font = NSFont(descriptor: desc, size: size) else { return base }
    return font
}

/// Background shared by both layouts: the paper gradient, top to bottom.
func drawBackdrop(_ ctx: CGContext, W: CGFloat, H: CGFloat, cs: CGColorSpace) {
    let gradient = CGGradient(colorsSpace: cs,
                              colors: [paperTop, paperBottom] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
}

/// The popup's blue→green header bar, as a short rounded rule.
func drawAccentRule(_ ctx: CGContext, cs: CGColorSpace, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    let rect = CGRect(x: x, y: y, width: width, height: height)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
    ctx.clip()
    let gradient = CGGradient(colorsSpace: cs, colors: [brandBlue, brandGreen] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.midY), end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
    ctx.restoreGState()
}

// MARK: - Rendering

func loadImage(_ url: URL) -> CGImage? {
    guard let image = NSImage(contentsOf: url) else { return nil }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

/// Mac window captures (⌘⇧4, Space) come with the window's drop shadow as
/// semi-transparent padding. Crop to the fully opaque window body so the
/// frame hugs the window; the rounded corners stay inside that box. Returns
/// the image unchanged when it has no alpha channel.
func trimShadow(_ image: CGImage) -> CGImage {
    guard image.alphaInfo != .none, image.alphaInfo != .noneSkipLast, image.alphaInfo != .noneSkipFirst else { return image }
    let w = image.width, h = image.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let data = ctx.data else { return image }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        for x in 0..<w where px[(y * w + x) * 4 + 3] >= 250 {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
    guard maxX >= minX, maxY >= minY else { return image }
    return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) ?? image
}

/// Draws one framed screenshot. All geometry is in output pixels, bottom-left
/// origin (CoreGraphics), so "top" means the high-y end.
func render(item: Item, set: ScreenSet, source: CGImage) -> CGImage? {
    let W = CGFloat(set.width), H = CGFloat(set.height)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: set.width, height: set.height,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        // noneSkipLast = RGBX, alpha byte ignored = opaque PNG.
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    drawBackdrop(ctx, W: W, H: H, cs: cs)

    // Headline, centred, two lines by convention ("\n" in the spec). Sized
    // off the shorter dimension so the Duo's squat canvas doesn't get a
    // headline taller than the shot.
    let headlineSize = min(W * 0.072, H * 0.034)
    let sublineSize  = headlineSize * 0.48
    let textWidth = W * 0.88
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = W * 0.008

    let headline = NSAttributedString(string: item.headline, attributes: [
        .font: roundedFont(size: headlineSize, weight: .bold),
        .foregroundColor: ink,
        .paragraphStyle: paragraph,
    ])
    let subline = NSAttributedString(string: item.subline ?? "", attributes: [
        .font: roundedFont(size: sublineSize, weight: .medium),
        .foregroundColor: inkMuted,
        .paragraphStyle: paragraph,
    ])
    let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
    let measure = CGSize(width: textWidth, height: .greatestFiniteMagnitude)
    let hB = headline.boundingRect(with: measure, options: opts)
    let sB = subline.boundingRect(with: measure, options: opts)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    var cursor = H - H * 0.065
    headline.draw(with: CGRect(x: (W - textWidth) / 2, y: cursor - hB.height, width: textWidth, height: hB.height), options: opts)
    cursor -= hB.height
    if item.subline != nil {
        cursor -= sublineSize * 0.6
        subline.draw(with: CGRect(x: (W - textWidth) / 2, y: cursor - sB.height, width: textWidth, height: sB.height), options: opts)
        cursor -= sB.height
    }
    NSGraphicsContext.restoreGraphicsState()

    // Accent rule, centred under the text.
    let ruleW = W * 0.16, ruleH = W * 0.007
    cursor -= H * 0.022
    drawAccentRule(ctx, cs: cs, x: (W - ruleW) / 2, y: cursor - ruleH, width: ruleW, height: ruleH)
    cursor -= ruleH

    // Device: 80% of the canvas width, black bezel, screenshot inset. It runs
    // off the bottom edge on purpose — the top of the screen is what sells,
    // and it hides the home indicator.
    let deviceWidth = W * 0.80
    let bezelWidth = deviceWidth * 0.022
    let screenWidth = deviceWidth - bezelWidth * 2
    let aspect = CGFloat(source.height) / CGFloat(source.width)
    let screenHeight = screenWidth * aspect
    let screenTop = cursor - H * 0.035 - bezelWidth
    let screenRect = CGRect(x: (W - screenWidth) / 2, y: screenTop - screenHeight,
                            width: screenWidth, height: screenHeight)
    let bezelRect = screenRect.insetBy(dx: -bezelWidth, dy: -bezelWidth)
    let screenRadius = set.cornerRadius * (screenWidth / W)
    let bezelRadius = screenRadius + bezelWidth

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.02), blur: W * 0.04,
                  color: CGColor(gray: 0, alpha: 0.22))
    ctx.setFillColor(bezel)
    ctx.addPath(CGPath(roundedRect: bezelRect, cornerWidth: bezelRadius, cornerHeight: bezelRadius, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: screenRect, cornerWidth: screenRadius, cornerHeight: screenRadius, transform: nil))
    ctx.clip()
    ctx.draw(source, in: screenRect)
    ctx.restoreGState()

    return ctx.makeImage()
}

/// Landscape variant for the Mac App Store: text left, window right.
func renderLandscape(item: Item, set: ScreenSet, source: CGImage) -> CGImage? {
    let W = CGFloat(set.width), H = CGFloat(set.height)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: set.width, height: set.height,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    drawBackdrop(ctx, W: W, H: H, cs: cs)

    // Text column: left ~34% of the canvas, vertically centred, left-aligned.
    let margin = W * 0.045
    let columnWidth = W * 0.34 - margin
    let headlineSize = W * 0.030
    let sublineSize  = W * 0.0165

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping

    let headline = NSAttributedString(string: item.headline, attributes: [
        .font: roundedFont(size: headlineSize, weight: .bold),
        .foregroundColor: ink,
        .paragraphStyle: paragraph,
    ])
    let subline = NSAttributedString(string: item.subline ?? "", attributes: [
        .font: roundedFont(size: sublineSize, weight: .medium),
        .foregroundColor: inkMuted,
        .paragraphStyle: paragraph,
    ])
    let measure = CGSize(width: columnWidth, height: .greatestFiniteMagnitude)
    let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
    let hB = headline.boundingRect(with: measure, options: opts)
    let sB = subline.boundingRect(with: measure, options: opts)
    let gapText = item.subline == nil ? 0 : sublineSize * 0.7
    let blockHeight = hB.height + gapText + sB.height
    var cursor = (H + blockHeight) / 2

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    headline.draw(with: CGRect(x: margin, y: cursor - hB.height, width: columnWidth, height: hB.height), options: opts)
    cursor -= hB.height + gapText
    if item.subline != nil {
        subline.draw(with: CGRect(x: margin, y: cursor - sB.height, width: columnWidth, height: sB.height), options: opts)
    }
    NSGraphicsContext.restoreGraphicsState()
    drawAccentRule(ctx, cs: cs, x: margin, y: cursor - sB.height - H * 0.03 - W * 0.004, width: W * 0.09, height: W * 0.004)

    // Window on the right, scaled to fit the remaining area with a margin,
    // keeping its aspect ratio. Mac windows already have rounded corners
    // baked into the capture, so the frame is a shadow plus a clip only.
    let areaX = W * 0.34
    let area = CGRect(x: areaX + margin * 0.5, y: margin,
                      width: W - areaX - margin * 1.5, height: H - margin * 2)
    let scale = min(area.width / CGFloat(source.width), area.height / CGFloat(source.height))
    let winW = CGFloat(source.width) * scale, winH = CGFloat(source.height) * scale
    let winRect = CGRect(x: area.midX - winW / 2, y: area.midY - winH / 2, width: winW, height: winH)
    let radius = set.cornerRadius * scale

    // Mac windows have no bezel: the fill under the capture only has to
    // carry the shadow and back the anti-aliased window edge, so it is the
    // window chrome's own light grey rather than the phone's black.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.01),
                  blur: W * 0.03,
                  color: CGColor(gray: 0, alpha: 0.25))
    ctx.setFillColor(CGColor(gray: 0.93, alpha: 1))
    ctx.addPath(CGPath(roundedRect: winRect.insetBy(dx: 1, dy: 1), cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: winRect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.draw(source, in: winRect)
    ctx.restoreGState()

    // Magnified inset, bottom-left of the text column, overlapping the
    // window's edge so it reads as "zoomed from there".
    if let c = item.callout {
        let sw = CGFloat(source.width), sh = CGFloat(source.height)
        let srcRect = CGRect(x: c.x * sw, y: c.y * sh, width: c.w * sw, height: c.h * sh)
        if let piece = source.cropping(to: srcRect) {
            let onScreenW = srcRect.width * scale, onScreenH = srcRect.height * scale
            let insetW = min(onScreenW * c.scale, columnWidth), insetH = onScreenH * (insetW / onScreenW)
            let pad = W * 0.004
            let insetRect = CGRect(x: margin, y: cursor - sB.height - insetH - H * 0.06, width: insetW, height: insetH)
            let frameRect = insetRect.insetBy(dx: -pad, dy: -pad)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -W * 0.006), blur: W * 0.02, color: CGColor(gray: 0, alpha: 0.4))
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.addPath(CGPath(roundedRect: frameRect, cornerWidth: pad * 3, cornerHeight: pad * 3, transform: nil))
            ctx.fillPath()
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: insetRect, cornerWidth: pad * 2, cornerHeight: pad * 2, transform: nil))
            ctx.clip()
            ctx.interpolationQuality = .high
            ctx.draw(piece, in: insetRect)
            ctx.restoreGState()
        }
    }

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "frame-screenshots", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "PNG encoding failed"])
    }
    try data.write(to: url)
}

// MARK: - Main

print(apply ? "Rendering → \(outputDir.path)" : "Dry run (add --apply to write) → \(outputDir.path)")
var problems = 0

for set in spec.sets {
    print("\n[\(set.name)] \(set.width)×\(set.height)")
    for item in set.items {
        let inputURL = resolve(item.input)
        let outputURL = outputDir.appendingPathComponent(item.output)
        guard let source = loadImage(inputURL) else {
            print("  ✗ \(item.output): missing input \(inputURL.path)")
            problems += 1
            continue
        }
        if !set.isLandscape && (source.width != set.width || source.height != set.height) {
            print("  ✗ \(item.output): input is \(source.width)×\(source.height), expected \(set.width)×\(set.height)")
            problems += 1
            continue
        }
        print("  • \(item.output)  ← \(inputURL.lastPathComponent)  “\(item.headline)”")
        guard apply else { continue }
        let framed = set.isLandscape
            ? renderLandscape(item: item, set: set, source: trimShadow(source))
            : render(item: item, set: set, source: source)
        guard let framed else {
            print("    ✗ render failed")
            problems += 1
            continue
        }
        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            try writePNG(framed, to: outputURL)
        } catch {
            print("    ✗ \(error.localizedDescription)")
            problems += 1
        }
    }
}

if problems > 0 {
    fail("\n\(problems) problem(s).")
}
print(apply ? "\nDone." : "\nAll inputs present. Re-run with --apply to write.")
