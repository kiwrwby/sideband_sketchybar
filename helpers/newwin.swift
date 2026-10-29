// Decides whether the frontmost app opened a large new window worth maximizing.
//   newwin <excluded-apps regex> [included-apps regex]  ->  prints "max" or nothing
// With an include regex only those apps qualify, otherwise everything except the
// excluded ones. A window id is considered once: windows the user shrank stay shrunk.
// Window ids are kept in $SBD_CACHE/seen_windows.
import AppKit

let ex = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "^$"
let inc = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
let cacheDir = ProcessInfo.processInfo.environment["SBD_CACHE"] ?? NSHomeDirectory() + "/.cache/sideband"
let seenF = cacheDir + "/seen_windows"
let first = !FileManager.default.fileExists(atPath: seenF)
let seen = Set((try? String(contentsOfFile: seenF, encoding: .utf8))?.split(separator: "\n").map(String.init) ?? [])
let fa = NSWorkspace.shared.frontmostApplication
let front = fa?.processIdentifier ?? -1
let fname = fa?.localizedName ?? ""   // Chrome PWAs all report app_mode_loader as the window owner
func hit(_ re: String, _ owner: String) -> Bool {
  fname.range(of: re, options: .regularExpression) != nil || owner.range(of: re, options: .regularExpression) != nil
}
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
var now = Set<String>()
var fresh = false
for w in list where (w[kCGWindowLayer as String] as? Int) == 0 {
  let id = "\(w[kCGWindowNumber as String] as? Int ?? 0)"
  now.insert(id)
  guard !first, !seen.contains(id), (w[kCGWindowOwnerPID as String] as? Int32) == front else { continue }
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  if !inc.isEmpty { if !hit(inc, owner) { continue } } else if hit(ex, owner) { continue }
  let b = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
  let wd = b["Width"] as? Double ?? 0, ht = b["Height"] as? Double ?? 0
  if wd >= 500 && ht >= 350 { fresh = true }   // dialogs and small windows stay alone
}
try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
try? now.sorted().joined(separator: "\n").write(toFile: seenF, atomically: true, encoding: .utf8)
if fresh { print("max") }
