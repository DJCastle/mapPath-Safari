#!/usr/bin/swift
//
// retouch-ipad-maps.swift — remove the lime-green Liquid Glass rendering
// smear the iOS 27.2 simulator paints across the top of Apple Maps' place
// card (screenshots/raw/ipad/maps.png, 1.2.2 set). It is a simulator
// artifact, identical in every capture, not something a device shows.
//
// Usage:
//     swift work/retouch-ipad-maps.swift <in.png> <out.png> [--apply]
//
// Only pixels inside the smear box whose green clearly exceeds blue are
// touched (the sky and the glass card are both blue-dominant, the status
// bar text is near-black), and each is replaced with the clean colour from
// the same row at the left edge, so the card's own gradient is preserved.
// Dry-run reports how many pixels would change; --apply writes the file.
//

import Foundation
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("Usage: retouch-ipad-maps.swift <in.png> <out.png> [--apply]\n".data(using: .utf8)!)
    exit(1)
}
let apply = args.contains("--apply")

guard let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Cannot read \(args[1])\n".data(using: .utf8)!)
    exit(1)
}

let width = cg.width, height = cg.height
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                          bytesPerRow: width * 4, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let data = ctx.data else { exit(1) }
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
let px = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

// Smear box in top-left pixel coordinates. A CGBitmapContext stores row 0
// at the top of the image, so no flip is needed when indexing the bytes.
let box = (x0: 150, x1: 820, y0: 0, y1: 200)
// The card's top edge: above it the clean sample is map sky, below it the
// glass itself. Both sampled from the far-left of the same row.
let cardTop = 62
func offset(_ x: Int, _ yTop: Int) -> Int { (yTop * width + x) * 4 }

var changed = 0
for yTop in box.y0..<box.y1 {
    let sampleX = yTop < cardTop ? 30 : 200
    let s = offset(sampleX, yTop)
    for x in box.x0..<box.x1 {
        let o = offset(x, yTop)
        let r = Int(px[o]), g = Int(px[o + 1]), b = Int(px[o + 2])
        // Lime: green well above blue, and not dark (so text survives).
        guard g > b + 4, g > 150, r > 100 else { continue }
        px[o] = px[s]; px[o + 1] = px[s + 1]; px[o + 2] = px[s + 2]
        changed += 1
    }
}

print("\(changed) pixel(s) \(apply ? "replaced" : "would be replaced") in \(box)")
guard apply else { exit(0) }
guard let out = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: out)
rep.size = NSSize(width: width, height: height)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("Wrote \(args[2])")
