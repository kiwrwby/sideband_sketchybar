// clickaway <command...>
// Runs only while a popup is open. The first click outside every SketchyBar window
// runs the command once and exits. Event driven, no polling. Gives up after
// 10 minutes so it can never linger.
import AppKit

let cmd = CommandLine.arguments.dropFirst().joined(separator: " ")

func insideSketchybar(_ p: CGPoint) -> Bool {
  let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
  for w in list where (w[kCGWindowOwnerName as String] as? String) == "sketchybar" {
    if let b = w[kCGWindowBounds as String] as? NSDictionary,
       let r = CGRect(dictionaryRepresentation: b), r.contains(p) { return true }
  }
  return false
}

NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
  let m = NSEvent.mouseLocation   // bottom-left origin; CGWindow bounds are top-left
  let h = NSScreen.screens.first?.frame.height ?? 0
  if insideSketchybar(CGPoint(x: m.x, y: h - m.y)) { return }   // bar clicks are handled by their own scripts
  let t = Process()
  t.launchPath = "/bin/bash"
  t.arguments = ["-c", cmd]
  try? t.run()
  t.waitUntilExit()
  exit(0)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 600) { exit(0) }
NSApplication.shared.setActivationPolicy(.prohibited)
NSApplication.shared.run()
