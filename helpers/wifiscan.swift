// Wi-Fi names for the bar and the Wi-Fi popup. macOS only gives SSIDs to apps that
// hold the Location permission, and only app bundles can hold it, so build.sh wraps
// this binary into WifiScan.app.
//   WifiScan scan      nearby networks -> $SBD_CACHE/wifiscan.txt
//                      line 1: ok | denied | undetermined, then name<TAB>RSSI, strongest first
//   WifiScan current   joined network  -> $SBD_CACHE/ssid.txt
//                      line 1: ok | denied | undetermined, line 2: name (empty if none)
import AppKit
import CoreLocation
import CoreWLAN

let cacheDir = ProcessInfo.processInfo.environment["SBD_CACHE"] ?? NSHomeDirectory() + "/.cache/sideband"
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "scan"
let out = URL(fileURLWithPath: cacheDir + (mode == "current" ? "/ssid.txt" : "/wifiscan.txt"))
func write(_ s: String) { try? s.write(to: out, atomically: true, encoding: .utf8) }

final class Scanner: NSObject, CLLocationManagerDelegate {
  let m = CLLocationManager()
  func start() { m.delegate = self; check() }
  func check() {
    switch m.authorizationStatus {
    case .authorizedAlways, .authorized: scan()
    case .notDetermined: m.requestWhenInUseAuthorization()
    default: write("denied\n"); exit(0)
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if m.authorizationStatus != .notDetermined { check() }
  }
  func scan() {
    if mode == "current" {
      write("ok\n" + (CWWiFiClient.shared().interface()?.ssid() ?? "") + "\n")
      exit(0)
    }
    var lines = ["ok"]
    if let i = CWWiFiClient.shared().interface(), let ns = try? i.scanForNetworks(withSSID: nil) {
      var best: [String: Int] = [:]
      for n in ns { if let s = n.ssid { best[s] = max(best[s] ?? -999, n.rssiValue) } }
      for (s, r) in best.sorted(by: { $0.value > $1.value }) { lines.append("\(s)\t\(r)") }
    }
    write(lines.joined(separator: "\n") + "\n")
    exit(0)
  }
}
let scanner = Scanner()
DispatchQueue.main.async { scanner.start() }
DispatchQueue.main.asyncAfter(deadline: .now() + 60) { write("undetermined\n"); exit(0) }   // unanswered permission prompt
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
