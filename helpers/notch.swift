// Left and right edge of the notch on a display, in points from that display's left
// edge: notch [DirectDisplayID]  ->  "790 1010". Default is the main display.
// Without a notch it prints the display centre twice.
import AppKit

let want = CommandLine.arguments.count > 1 ? UInt32(CommandLine.arguments[1]) : nil
let key = NSDeviceDescriptionKey("NSScreenNumber")
let screen = NSScreen.screens.first(where: { want == nil || ($0.deviceDescription[key] as? UInt32) == want })
  ?? NSScreen.screens.first
if let s = screen {
  if let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
    print(Int(l.maxX - s.frame.minX), Int(r.minX - s.frame.minX))
  } else {
    let c = Int(s.frame.width / 2)
    print(c, c)
  }
}
