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

// Sky ramp. Closes the circle: 24:00 must equal 00:00 or the colour seams at midnight.
assert(skyTint(hour: 24) == skyTint(hour: 0))

// Every channel stays in gamut across all 1440 minutes of the day.
for m in 0..<1440 {
    let c = skyTint(hour: m / 60, minute: m % 60)
    assert((0...1).contains(c.r) && (0...1).contains(c.g) && (0...1).contains(c.b))
}

// Night is bluest (blue exceeds red); noon is warmest (red exceeds blue).
let midnight = skyTint(hour: 0)
let noon = skyTint(hour: 12)
assert(midnight.b > midnight.r)
assert(noon.r > noon.b)
assert(noon.r > midnight.r)

// Interpolation actually moves between keyframes rather than stepping.
let dawnEarly = skyTint(hour: 6, minute: 0)
let dawnMid = skyTint(hour: 6, minute: 30)
let dawnLate = skyTint(hour: 7, minute: 0)
assert(dawnEarly.r < dawnMid.r && dawnMid.r < dawnLate.r)

// Out-of-range input clamps rather than trapping.
assert(skyTint(hour: 99) == skyTint(hour: 24))
assert(skyTint(hour: -5) == skyTint(hour: 0))

// The row carries the tint through.
assert(zoneInfo(for: "Asia/Tokyo", at: d, local: sf)!.sky == skyTint(hour: 8, minute: 0))

// Ruler offset: clamping and snapping.
let step5: TimeInterval = 300  // 5-minute grid

// Snaps to the grid, including from a deliberately off-grid start.
assert(clampedOffset(raw: 420, snap: step5).offset == 300)   // 7m  -> 5m
assert(clampedOffset(raw: 460, snap: step5).offset == 600)   // 7m40 -> 10m

// A step of n moves offset by exactly n * snap, even starting off-grid.
let offGrid = clampedOffset(raw: 420, snap: step5).offset    // 300
assert(clampedOffset(raw: offGrid + 2 * step5, snap: step5).offset == offGrid + 2 * step5)
assert(clampedOffset(raw: offGrid - 1 * step5, snap: step5).offset == offGrid - step5)

// Result always lands on the grid.
for r in stride(from: -7000.0, through: 7000.0, by: 137.0) {
    let o = clampedOffset(raw: r, snap: step5).offset
    assert(o.truncatingRemainder(dividingBy: step5) == 0)
}

// Clamps both directions, and clamps raw too — so one step back from the limit moves
// immediately rather than first unwinding invisible accumulated distance.
let pinned = clampedOffset(raw: maxShift * 10, snap: step5)
assert(pinned.offset == maxShift && pinned.raw == maxShift)
assert(clampedOffset(raw: pinned.raw - step5, snap: step5).offset == maxShift - step5)

let pinnedBack = clampedOffset(raw: -maxShift * 10, snap: step5)
assert(pinnedBack.offset == -maxShift && pinnedBack.raw == -maxShift)
assert(clampedOffset(raw: pinnedBack.raw + step5, snap: step5).offset == -maxShift + step5)

// Reset zeroes both halves.
let cleared = clampedOffset(raw: 0, snap: step5)
assert(cleared.raw == 0 && cleared.offset == 0)

// A zero snap must not divide by zero.
assert(clampedOffset(raw: 420, snap: 0).offset == 420)

print("all checks passed")
