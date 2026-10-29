// Opens Control Center the way the fn+C shortcut does.
import CoreGraphics
import Darwin

let source = CGEventSource(stateID: .hidSystemState)
for pressed in [true, false] {
  if let event = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: pressed) {
    event.flags = .maskSecondaryFn
    event.post(tap: .cghidEventTap)
  }
  usleep(80_000)
}
