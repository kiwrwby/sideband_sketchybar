// Calendar events through EventKit (icalBuddy reports multi-day all-day events one
// day short). Needs Calendar access for the process that runs it.
//   events <YYYY-MM-01> [calendarID,...]   every event touching that month:
//                                          date<TAB>text   date = MM.DD or MM.DD-MM.DD
//   events today                           today's unfinished timed events: HH:mm<TAB>title
//   events calid <calendar name>           identifier of the calendar with that title
// Exit 3 when Calendar access was denied.
import EventKit

let a = CommandLine.arguments
let store = EKEventStore()
let status = EKEventStore.authorizationStatus(for: .event)
if status == .denied || status == .restricted { exit(3) }

if a.count > 1 && a[1] == "today" {
  let cal = Calendar.current, now = Date()
  let st = cal.startOfDay(for: now), en = cal.date(byAdding: .day, value: 1, to: st)!
  let hm = DateFormatter(); hm.dateFormat = "HH:mm"
  for e in store.events(matching: store.predicateForEvents(withStart: st, end: en, calendars: nil))
      .filter({ !$0.isAllDay && $0.endDate > now }).sorted(by: { $0.startDate < $1.startDate }) {
    print("\(hm.string(from: e.startDate))\t\(e.title ?? "")")
  }
  exit(0)
}
if a.count > 2 && a[1] == "calid" {
  for c in store.calendars(for: .event) where c.title == a[2] { print(c.calendarIdentifier); exit(0) }
  exit(1)
}
let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd"
guard a.count > 1, let from = d.date(from: a[1]) else { exit(1) }
let cal = Calendar.current
let to = cal.date(byAdding: .month, value: 1, to: from)!
let ids = a.count > 2 ? Set(a[2].split(separator: ",").map(String.init)) : []
let cals = ids.isEmpty ? nil : store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
let md = DateFormatter(); md.dateFormat = "MM.dd"
let hm = DateFormatter(); hm.dateFormat = "HH:mm"
for e in store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: cals))
    .sorted(by: { $0.startDate < $1.startDate }) {
  // An all-day event ends at 23:59 of its last day. A timed event ending exactly at midnight belongs to the day before.
  let last = cal.startOfDay(for: e.endDate.addingTimeInterval(e.isAllDay ? 0 : -1))
  let first = cal.startOfDay(for: e.startDate)
  var key = md.string(from: first)
  if last > first { key += "-" + md.string(from: last) }
  let t = e.isAllDay ? "" : hm.string(from: e.startDate) + " "
  print("\(key)\t\(t)\(e.title ?? "")")
}
