#!/usr/bin/env swift
//
//  shadow-icon.swift
//  Renders a transparent icon onto an output PNG of the requested size, with
//  a soft drop shadow underneath for depth. The output is *transparent* (no
//  background composited in) so it can sit on top of any colored or image
//  background in the launch screen.
//
//  Usage: swift shadow-icon.swift <input.png> <output.png> <out-size>
//
//  Different from scripts/flatten-icon.swift (which fills with opaque white
//  for the Mac App Store large-icon requirement). This one preserves alpha.
//

import Foundation
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 4, let outSize = Int(args[3]) else {
    print("usage: shadow-icon.swift <input> <output> <size>")
    exit(1)
}
let inputPath = args[1]
let outputPath = args[2]

guard let nsImg = NSImage(byReferencingFile: inputPath),
      let cg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("failed to load \(inputPath)"); exit(1)
}

// 10% padding around the icon so the shadow has room to render without being
// clipped by the bounds. The icon design itself draws inside the inner 80%.
let pad = Int(Double(outSize) * 0.10)
let iconRect = CGRect(
    x: pad, y: pad,
    width: outSize - 2 * pad,
    height: outSize - 2 * pad
)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: outSize, height: outSize,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
ctx.interpolationQuality = .high

// Subtle drop shadow — proportional to output size, slight downward offset.
// Negative Y in Core Graphics coords means the shadow falls *below* the icon.
let shadowOffset = CGSize(width: 0, height: -CGFloat(outSize) * 0.018)
let shadowBlur = CGFloat(outSize) * 0.06
let shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)

// Draw the icon. Core Graphics applies the shadow to whatever's drawn.
ctx.draw(cg, in: iconRect)

guard let result = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:])
else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath) at \(outSize)×\(outSize) with drop shadow")
