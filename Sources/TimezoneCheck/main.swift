import Foundation
import TimezoneCore

// Self-check for the date math. Run: swift run TimezoneCheck
// All cases use fixed instants — never Date() — so they cannot drift or flake.

private func utc(_ iso: String) -> Date {
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: iso)!
}

let sf = TimeZone(identifier: "America/Los_Angeles")!
let tokyo = TimeZone(identifier: "Asia/Tokyo")!
let utcZone = TimeZone(identifier: "UTC")!
let kolkata = TimeZone(identifier: "Asia/Kolkata")!

// Date-line rollover.
// 2026-07-20 13:40Z = Mon 06:40 in SF, Mon 22:40 in Tokyo — still the same day.
assert(dayWord(tokyo, from: sf, at: utc("2026-07-20T13:40:00Z")) == "today")
// 2026-07-20 23:00Z = Mon 16:00 in SF, Tue 08:00 in Tokyo.
assert(dayWord(tokyo, from: sf, at: utc("2026-07-20T23:00:00Z")) == "tomorrow")
// Same instant the other way round: SF is a day behind Tokyo.
assert(dayWord(sf, from: tokyo, at: utc("2026-07-20T23:00:00Z")) == "yesterday")

// DST: Tokyo has none, SF does, so the gap differs between January and July.
assert(offsetText(tokyo, from: sf, at: utc("2026-01-15T12:00:00Z")) == "+17h")
assert(offsetText(tokyo, from: sf, at: utc("2026-07-15T12:00:00Z")) == "+16h")

// Half-hour zones.
assert(offsetText(kolkata, from: utcZone, at: utc("2026-07-20T12:00:00Z")) == "+5h30m")
assert(offsetText(utcZone, from: kolkata, at: utc("2026-07-20T12:00:00Z")) == "-5h30m")
assert(offsetText(utcZone, from: utcZone, at: utc("2026-07-20T12:00:00Z")) == "same")

// Vibe boundaries, default hours: awake 06–21, work 08–17.
assert(vibe(hour: 5) == .asleep)
assert(vibe(hour: 6) == .fringe)
assert(vibe(hour: 7) == .fringe)
assert(vibe(hour: 8) == .working)
assert(vibe(hour: 16) == .working)
assert(vibe(hour: 17) == .fringe)
assert(vibe(hour: 20) == .fringe)
assert(vibe(hour: 21) == .asleep)

// Custom hours shift the bands.
let nightOwl = Hours(wake: 11, workStart: 14, workEnd: 23, sleep: 3)
assert(vibe(hour: 9, hours: nightOwl) == .asleep)
assert(vibe(hour: 12, hours: nightOwl) == .fringe)
assert(vibe(hour: 15, hours: nightOwl) == .working)
// Waking range wraps past midnight: 01:00 is still awake, 04:00 is not.
assert(vibe(hour: 1, hours: nightOwl) == .fringe)
assert(vibe(hour: 4, hours: nightOwl) == .asleep)

// Work range itself may wrap: a night shift running 22:00–06:00.
let nightShift = Hours(wake: 20, workStart: 22, workEnd: 6, sleep: 8)
assert(vibe(hour: 23, hours: nightShift) == .working)
assert(vibe(hour: 2, hours: nightShift) == .working)
assert(vibe(hour: 7, hours: nightShift) == .fringe)
assert(vibe(hour: 12, hours: nightShift) == .asleep)

// Degenerate range (start == end) is empty, not all-day.
assert(vibe(hour: 12, hours: Hours(wake: 7, workStart: 9, workEnd: 9, sleep: 22)) == .fringe)

// Weekend is per zone: 2026-07-26 20:00Z is Sun 13:00 in SF but already Mon 05:00 in Tokyo.
let monInTokyo = utc("2026-07-26T20:00:00Z")
assert(zoneInfo(for: "America/Los_Angeles", at: monInTokyo, local: sf)!.isWeekend)
assert(!zoneInfo(for: "Asia/Tokyo", at: monInTokyo, local: sf)!.isWeekend)

// Full row.
let d = utc("2026-07-20T23:00:00Z")
let row = zoneInfo(for: "Asia/Tokyo", at: d, local: sf)!
assert(row.label == "Tokyo")
assert(row.time == "08:00")
assert(row.offsetText == "+16h")
assert(row.dayWord == "tomorrow")
assert(row.vibe == .working)  // 08:00 is workStart under the default hours
assert(!row.isLocal)

let here = zoneInfo(for: "America/Los_Angeles", at: d, local: sf)!
assert(here.isLocal)
assert(here.offsetText == "—")
assert(here.time == "16:00")

// Labels, search, unknown zones.
assert(cityLabel("America/Argentina/Buenos_Aires") == "Buenos Aires")
assert(cityLabel("UTC") == "UTC")
assert(searchZones("tokyo") == ["Asia/Tokyo"])
assert(searchZones("").count > 100)
assert(searchZones("nope-nowhere").isEmpty)
assert(zoneInfo(for: "Mars/Olympus_Mons", at: d, local: sf) == nil)

print("all checks passed")
