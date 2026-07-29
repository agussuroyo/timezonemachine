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

// Abbreviations come from tzdata, flip with DST, and are nil when tzdata only has a number.
assert(abbreviation(sf, at: utc("2026-01-15T12:00:00Z")) == "PST")
assert(abbreviation(sf, at: utc("2026-07-15T12:00:00Z")) == "PDT")
assert(abbreviation(tokyo, at: utc("2026-07-15T12:00:00Z")) == "JST")
// Foundation normalises TimeZone(identifier: "UTC").identifier to "GMT", so tzdata answers GMT.
assert(abbreviation(utcZone, at: utc("2026-07-15T12:00:00Z")) == "GMT")
// Southern hemisphere: DST is on in January, off in July.
let sydney = TimeZone(identifier: "Australia/Sydney")!
assert(abbreviation(sydney, at: utc("2026-01-15T12:00:00Z")) == "AEDT")
assert(abbreviation(sydney, at: utc("2026-07-15T12:00:00Z")) == "AEST")
// Dhaka has no name in tzdata, only "+06" — dropped rather than repeated as an offset.
assert(abbreviation(TimeZone(identifier: "Asia/Dhaka")!, at: utc("2026-07-15T12:00:00Z")) == nil)
// Reading an abbreviation must not leave TZ set behind, or every later zone reads wrong.
assert(getenv("TZ") == nil)
assert(abbreviation(tokyo, at: utc("2026-07-15T12:00:00Z")) == "JST")

// Scrubbing across the US spring-forward instant (2026-03-08 07:00Z) flips the whole caption.
assert(zoneInfo(for: "America/New_York", at: utc("2026-03-08T06:59:00Z"), local: tokyo)!
    .offsetText == "EST · -14h")
assert(zoneInfo(for: "America/New_York", at: utc("2026-03-08T07:01:00Z"), local: tokyo)!
    .offsetText == "EDT · -13h")

// The caption pairs the name with the distance, and drops whichever half says nothing.
assert(zoneCaption(tokyo, from: sf, at: utc("2026-07-15T12:00:00Z")) == "JST · +16h")
assert(zoneCaption(tokyo, from: tokyo, at: utc("2026-07-15T12:00:00Z")) == "JST")
let dhaka = TimeZone(identifier: "Asia/Dhaka")!
assert(zoneCaption(dhaka, from: sf, at: utc("2026-07-15T12:00:00Z")) == "+13h")
assert(zoneCaption(dhaka, from: dhaka, at: utc("2026-07-15T12:00:00Z")) == "—")

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
assert(row.offsetText == "JST · +16h")
assert(row.dayWord == "tomorrow")
assert(row.vibe == .working)  // 08:00 is workStart under the default hours
assert(!row.isLocal)

let here = zoneInfo(for: "America/Los_Angeles", at: d, local: sf)!
assert(here.isLocal)
assert(here.offsetText == "PDT")  // own row: abbreviation only, no self-offset
assert(zoneInfo(for: "Asia/Jakarta", at: d, local: TimeZone(identifier: "Asia/Jakarta")!)!
    .offsetText == "WIB")         // own row, named zone: abbreviation carries it
assert(zoneInfo(for: "Asia/Dhaka", at: d, local: TimeZone(identifier: "Asia/Dhaka")!)!
    .offsetText == "—")           // own row, unnamed zone: nothing to show
assert(here.time == "16:00")

// Seconds are zero-padded and taken from the instant (23:00:00Z here).
assert(zoneInfo(for: "Asia/Tokyo", at: d, local: sf)!.seconds == "00")
assert(zoneInfo(for: "Asia/Tokyo", at: utc("2026-07-20T23:00:07Z"), local: sf)!.seconds == "07")

// Labels, search, unknown zones.
assert(cityLabel("America/Argentina/Buenos_Aires") == "Buenos Aires")
assert(cityLabel("UTC") == "UTC")
assert(searchZones("tokyo") == ["Asia/Tokyo"])
assert(searchZones("").count > 100)
assert(searchZones("nope-nowhere").isEmpty)
// Findable by country or region, which no identifier spells.
assert(searchZones("bangladesh").contains("Asia/Dhaka"))
assert(searchZones("india").contains("Asia/Calcutta"))
assert(searchZones("vietnam").contains("Asia/Ho_Chi_Minh"))
// Findable with a space where the identifier has an underscore.
assert(searchZones("new york").contains("America/New_York"))
assert(searchZones("ho chi minh").contains("Asia/Ho_Chi_Minh"))

// Findable by UTC offset, in the spellings people actually type.
let july = utc("2026-07-20T12:00:00Z")
for spelling in ["utc+7", "UTC+7", "gmt+7", "+7", "utc +7", "utc+07:00"] {
    assert(searchZones(spelling, at: july).contains("Asia/Jakarta"), spelling)
    assert(!searchZones(spelling, at: july).contains("Asia/Tokyo"), spelling)  // Tokyo is +9
}
assert(searchZones("+5:30", at: july).contains("Asia/Calcutta"))
assert(searchZones("utc-7", at: july).contains("America/Los_Angeles"))  // PDT in July
assert(searchZones("+0", at: july).contains("GMT"))

// DST-correct: London is +1 in July and +0 in January, and the query follows.
assert(searchZones("+1", at: july).contains("Europe/London"))
assert(!searchZones("+1", at: utc("2026-01-15T12:00:00Z")).contains("Europe/London"))

// Bare "utc"/"gmt" is the zero offset, because the known-zone list has no "UTC" to match.
assert(gmtQuery("utc") == 0)
assert(searchZones("utc", at: july).contains("GMT"))

// Not offset queries: fall through to text search rather than matching nothing.
assert(gmtQuery("+99") == nil)      // no zone is +99, and 99 is not an hour
assert(gmtQuery("+1:70") == nil)    // 70 is not a minute
assert(gmtQuery("+1:2:3") == nil)
assert(gmtQuery("tokyo") == nil)

// Findable by tzdata abbreviation, on either side of DST.
assert(searchZones("aest").contains("Australia/Sydney"))
assert(searchZones("AEDT").contains("Australia/Sydney"))
assert(searchZones("jst").contains("Asia/Tokyo"))
assert(searchZones("wib").contains("Asia/Jakarta"))
assert(searchZones("pst").contains("America/Los_Angeles"))
assert(searchZones("pdt").contains("America/Los_Angeles"))
// A text match wins, so a city name is never crowded out by abbreviations.
assert(searchZones("tokyo") == ["Asia/Tokyo"])
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
