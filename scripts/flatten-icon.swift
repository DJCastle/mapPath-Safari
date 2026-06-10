#!/usr/bin/swift
//
// flatten-icon.swift — composite the transparent app icon onto an opaque
// background and write a PNG with no alpha channel.
//
// Usage:
//     swift scripts/flatten-icon.swift <input.png> <output.png> <size> [#RRGGBB]
//
// Why this exists: the Mac App Store validator (error 90717) rejects any
// app icon whose 1024×1024 (or any) variant contains an alpha channel.
// The canonical icon source in app-icon/MapPath.icon/Assets/icon.png is
// transparent (good for Safari toolbar icons), so the sync script runs
// this to produce opaque versions for the AppIcon.appiconset.
//

import Foundation
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write("Usage: flatten-icon.swift <input.png> <output.png> <size> [#RRGGBB]\n".data(using: .utf8)!)
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]
guard let size = Int(args[3]), size > 0 else {
    FileHandle.standardError.write("Invalid size: \(args[3])\n".data(using: .utf8)!)
    exit(1)
}

// Background color (default white).
var bg = NSColor.white
if args.count >= 5 {
    let hex = args[4].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    if hex.count == 6, let val = UInt32(hex, radix: 16) {
        let r = CGFloat((val >> 16) & 0xff) / 255
        let g = CGFloat((val >> 8) & 0xff) / 255
        let b = CGFloat(val & 0xff) / 255
        bg = NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}

guard let inputImage = NSImage(contentsOfFile: inputPath),
      let srcCG = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Failed to load \(inputPath)\n".data(using: .utf8)!)
    exit(1)
}

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    // noneSkipLast = RGBX with alpha byte ignored = opaque output.
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    FileHandle.standardError.write("Failed to create CGContext\n".data(using: .utf8)!)
    exit(1)
}

ctx.setFillColor(bg.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

ctx.interpolationQuality = .high
ctx.draw(srcCG, in: CGRect(x: 0, y: 0, width: size, height: size))

guard let outputCG = ctx.makeImage() else {
    FileHandle.standardError.write("Failed to make output CGImage\n".data(using: .utf8)!)
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: outputCG)
rep.size = NSSize(width: size, height: size)
guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

try! data.write(to: URL(fileURLWithPath: outputPath))
