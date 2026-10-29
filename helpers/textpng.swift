// One line of text to a PNG at 2x: textpng "<text>" <0xAARRGGBB> <pt> <out.png> [trim] [sys]
// SketchyBar text has one colour per item. Where a popup row needs a second colour
// or exact right alignment, the second part is laid over as a background image.
//   trim  crop blank columns so the image width equals the ink width
//   sys   use the system monospaced font (glyphs such as the minus sign differ)
// The font is $SBD_FONT_FAMILY and $SBD_FONT_STYLE, resolved the way SketchyBar does, so
// the image matches the text around it.
import AppKit

let a = CommandLine.arguments
guard a.count >= 5, let v = UInt32(a[2].dropFirst(2), radix: 16), let pt = Double(a[3]) else { exit(1) }
let col = NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                  blue: CGFloat(v & 255) / 255, alpha: CGFloat(v >> 24) / 255)
let env = ProcessInfo.processInfo.environment
let attrs: [CFString: Any] = [kCTFontFamilyNameAttribute: env["SBD_FONT_FAMILY"] ?? "JetBrains Mono",
                              kCTFontStyleNameAttribute: env["SBD_FONT_STYLE"] ?? "Regular", kCTFontSizeAttribute: pt * 2]
let ct = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attrs as CFDictionary), 0, nil)
let font = a.contains("sys") ? NSFont.monospacedSystemFont(ofSize: pt * 2, weight: .regular) : unsafeBitCast(ct, to: NSFont.self)
let s = NSAttributedString(string: a[1], attributes: [.font: font, .foregroundColor: col])
let sz = s.size()
let pad = a.contains("trim") ? 6 : 0
let w = Int(ceil(sz.width)) + pad, h = Int(ceil(sz.height))
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
s.draw(at: NSPoint(x: pad / 2, y: 0))
NSGraphicsContext.restoreGraphicsState()
var out = rep
if a.contains("trim") {
  let cols = (0..<w).filter { x in (0..<h).contains { y in (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.15 } }
  if let c0 = cols.first, let x1 = cols.last {
    let x0 = (x1 - c0 + 1) % 2 == 1 ? c0 - 1 : c0   // whole-point width at 2x
    if let cg = rep.cgImage?.cropping(to: CGRect(x: x0, y: 0, width: x1 - x0 + 1, height: h)) { out = NSBitmapImageRep(cgImage: cg) }
  }
}
try? out.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: a[4]))
