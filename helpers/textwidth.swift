// Text measurement that matches what SketchyBar draws. The font is resolved the way
// SketchyBar does it (a CoreText descriptor from family and style), so any font works,
// proportional ones included, and a name that is not installed measures as the
// fallback SketchyBar falls back to.
//
//   textwidth <family> <style> <size> width <text>      width in points, rounded up
//   textwidth <family> <style> <size> prefixes <text>   widths of the prefixes of 0..n characters
//   textwidth <family> <style> <size> fit <max>         stdin: tab separated lines; field 2 is cut
//                                                       to <max> points and ends in an ellipsis
//   textwidth <family> <style> <size> exists            1 if the family is installed or one of Apple's
//                                                       system families (SF Pro, SF Mono), else 0
//   textwidth <family> <style> <size> adv               advance of one cell of the monospaced
//                                                       font for this family (the system
//                                                       monospaced font if the family is not
//                                                       fixed-pitch). For grids such as the calendar.
import AppKit
import CoreText

let a = CommandLine.arguments
guard a.count >= 5, let size = Double(a[3]) else { exit(2) }

func ctFont(_ family: String, _ style: String, _ size: CGFloat) -> CTFont {
  let attrs: [CFString: Any] = [kCTFontFamilyNameAttribute: family, kCTFontStyleNameAttribute: style, kCTFontSizeAttribute: size]
  return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attrs as CFDictionary), 0, nil)
}
func monoFont(_ family: String, _ style: String, _ size: CGFloat) -> CTFont {
  let f = ctFont(family, style, size)
  if CTFontGetSymbolicTraits(f).contains(.traitMonoSpace) { return f }
  return NSFont.monospacedSystemFont(ofSize: size, weight: .regular) as CTFont
}
func width(_ s: String, _ font: CTFont) -> Double {
  if s.isEmpty { return 0 }
  let str = NSAttributedString(string: s, attributes: [.font: font as Any])
  return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(str), nil, nil, nil)
}
func up(_ w: Double) -> Int { Int((w - 0.001).rounded(.up)) }   // 36.0000001 must not become 37

let mode = a[4]
if mode == "exists" {
  let fam = a[1]
  let attrs = [kCTFontFamilyNameAttribute: fam] as CFDictionary
  let found = CTFontDescriptorCreateMatchingFontDescriptor(CTFontDescriptorCreateWithAttributes(attrs), nil) != nil
  print(found || fam.hasPrefix("SF ") || fam.hasPrefix(".SF") || fam == "System Font" ? 1 : 0)
  exit(0)
}
if mode == "adv" {
  print(String(format: "%.3f", width("0", monoFont(a[1], a[2], CGFloat(size)))))
  exit(0)
}
let font = ctFont(a[1], a[2], CGFloat(size))
switch mode {
case "width":
  print(up(width(a.count > 5 ? a[5] : "", font)))
case "prefixes":
  let chars = Array(a.count > 5 ? a[5] : "")
  print((0...chars.count).map { String(up(width(String(chars.prefix($0)), font))) }.joined(separator: " "))
case "fit":
  let maxW = Double(a.count > 5 ? a[5] : "120") ?? 120
  while let line = readLine(strippingNewline: true) {
    var f = line.components(separatedBy: "\t")
    if f.count > 1, width(f[1], font) > maxW {
      var chars = Array(f[1])
      while !chars.isEmpty, width(String(chars) + "…", font) > maxW { chars.removeLast() }
      f[1] = String(chars).trimmingCharacters(in: .whitespaces) + "…"
    }
    print(f.joined(separator: "\t"))
  }
default: exit(2)
}
