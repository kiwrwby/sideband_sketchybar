// Output devices through CoreAudio and IOBluetooth. Nothing to install; the list
// matches Control Center's Sound output list.
//   audio                  one line per device: id<TAB>name<TAB>kind<TAB>1 if current
//                          kind = builtin | bluetooth | other
//   audio set <id>         make a device the default output. Exit 1 on failure
//   audio bt               paired but disconnected Bluetooth audio devices: address<TAB>name (~4 s)
//   audio connect <addr>   connect, wait up to 8 s for it to appear, make it the default output
//   audio watch <command>  run <command> whenever mute or the default device changes.
//                          Exits when $SBD_BAR_PID dies. SketchyBar's volume_change misses mute.
import CoreAudio
import Foundation
import IOBluetooth

func prop(_ sel: AudioObjectPropertySelector,
          _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
  AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}
let sys = AudioObjectID(kAudioObjectSystemObject)

func defaultOut() -> AudioDeviceID {
  var a = prop(kAudioHardwarePropertyDefaultOutputDevice)
  var id = AudioDeviceID(0)
  var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
  AudioObjectGetPropertyData(sys, &a, 0, nil, &sz, &id)
  return id
}
func u32(_ id: AudioObjectID, _ sel: AudioObjectPropertySelector) -> UInt32 {
  var a = prop(sel)
  var v = UInt32(0)
  var sz = UInt32(4)
  AudioObjectGetPropertyData(id, &a, 0, nil, &sz, &v)
  return v
}
func name(_ id: AudioObjectID) -> String {
  var a = prop(kAudioObjectPropertyName)
  var s: Unmanaged<CFString>?
  var sz = UInt32(MemoryLayout<CFString?>.size)
  guard AudioObjectGetPropertyData(id, &a, 0, nil, &sz, &s) == noErr, let v = s?.takeRetainedValue() else { return "?" }
  return v as String
}
func outChannels(_ id: AudioObjectID) -> Int {
  var a = prop(kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeOutput)
  var sz = UInt32(0)
  guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &sz) == noErr, sz > 0 else { return 0 }
  let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(sz), alignment: 16)
  defer { buf.deallocate() }
  guard AudioObjectGetPropertyData(id, &a, 0, nil, &sz, buf) == noErr else { return 0 }
  return UnsafeMutableAudioBufferListPointer(buf.assumingMemoryBound(to: AudioBufferList.self))
    .reduce(0) { $0 + Int($1.mNumberChannels) }
}
func outputs() -> [(AudioDeviceID, String, String)] {
  var a = prop(kAudioHardwarePropertyDevices)
  var sz = UInt32(0)
  AudioObjectGetPropertyDataSize(sys, &a, 0, nil, &sz)
  var ids = [AudioDeviceID](repeating: 0, count: Int(sz) / MemoryLayout<AudioDeviceID>.size)
  AudioObjectGetPropertyData(sys, &a, 0, nil, &sz, &ids)
  var out: [(AudioDeviceID, String, String)] = []
  for id in ids where outChannels(id) > 0 && u32(id, kAudioDevicePropertyIsHidden) == 0 {
    let t = u32(id, kAudioDevicePropertyTransportType)
    if t == kAudioDeviceTransportTypeAggregate || t == kAudioDeviceTransportTypeAutoAggregate { continue }
    let kind = t == kAudioDeviceTransportTypeBuiltIn ? "builtin"
      : (t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE) ? "bluetooth" : "other"
    out.append((id, name(id), kind))
  }
  return out
}
func setDefault(_ id: AudioDeviceID) -> Bool {
  var a = prop(kAudioHardwarePropertyDefaultOutputDevice)
  var v = id
  let r = AudioObjectSetPropertyData(sys, &a, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &v)
  return r == noErr && defaultOut() == id
}

let args = CommandLine.arguments
if args.count >= 3, args[1] == "set", let id = AudioDeviceID(args[2]) { exit(setDefault(id) ? 0 : 1) }

if args.count >= 2, args[1] == "bt" {
  let live = Set(outputs().map { $0.1 })
  for d in (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
  where d.deviceClassMajor == 4 && !d.isConnected() {   // 4 = audio
    if let n = d.name, !live.contains(n) { print("\(d.addressString ?? "")\t\(n)") }
  }
  exit(0)
}

if args.count >= 3, args[1] == "connect", let d = IOBluetoothDevice(addressString: args[2]) {
  guard d.openConnection() == kIOReturnSuccess else { exit(1) }
  for _ in 0..<40 {   // 40 x 0.2 s until it shows up as an audio device
    if let o = outputs().first(where: { $0.2 == "bluetooth" && $0.1 == d.name }) { exit(setDefault(o.0) ? 0 : 1) }
    usleep(200_000)
  }
  exit(1)
}

if args.count >= 3, args[1] == "watch" {
  let cmd = args[2]
  let barPid = pid_t(ProcessInfo.processInfo.environment["SBD_BAR_PID"] ?? "") ?? 0
  func run() {
    let t = Process()
    t.launchPath = "/bin/sh"
    t.arguments = ["-c", cmd]
    try? t.run()
  }
  var dev = AudioDeviceID(0)
  var muteAddr = prop(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
  let onMute: AudioObjectPropertyListenerBlock = { _, _ in run() }
  func attach() {
    if dev != 0 { AudioObjectRemovePropertyListenerBlock(dev, &muteAddr, DispatchQueue.main, onMute) }
    dev = defaultOut()
    AudioObjectAddPropertyListenerBlock(dev, &muteAddr, DispatchQueue.main, onMute)
  }
  attach()
  var defAddr = prop(kAudioHardwarePropertyDefaultOutputDevice)
  AudioObjectAddPropertyListenerBlock(sys, &defAddr, DispatchQueue.main) { _, _ in attach(); run() }   // follow the new device's mute
  Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    if barPid > 0 && kill(barPid, 0) != 0 { exit(0) }
  }
  RunLoop.main.run()
}

let cur = defaultOut()
for (id, n, kind) in outputs() { print("\(id)\t\(n)\t\(kind)\t\(id == cur ? 1 : 0)") }
