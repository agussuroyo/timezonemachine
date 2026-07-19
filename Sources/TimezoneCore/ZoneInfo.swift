import Foundation

/// How reachable someone in this zone probably is, by their local hour.
public enum Vibe: Sendable {
    case working  // inside work hours
    case fringe   // awake, but off the clock
    case asleep   // outside waking hours
}

/// The four hour boundaries that drive `Vibe`. Defaults reproduce 9–18 work, 7–22 awake.
public struct Hours: Sendable, Equatable {
    public var wake: Int
    public var workStart: Int
    public var workEnd: Int
    public var sleep: Int

    public static let standard = Hours(wake: 6, workStart: 8, workEnd: 17, sleep: 21)

    public init(wake: Int, workStart: Int, workEnd: Int, sleep: Int) {
        self.wake = wake
        self.workStart = workStart
        self.workEnd = workEnd
        self.sleep = sleep
    }
}

/// Half-open [start, end) on a 24-hour circle, so a range may wrap past midnight
/// — someone who sleeps at 01:00 has a waking range of 07:00–01:00.
func inRange(_ hour: Int, _ start: Int, _ end: Int) -> Bool {
    if start == end { return false }
    return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
}

/// Everything one row of the popover needs, precomputed so the view does no date math.
public struct ZoneInfo: Identifiable, Sendable {
    public let id: String        // IANA identifier, e.g. "Asia/Tokyo"
    public let label: String     // "Tokyo"
    public let time: String      // "23:40"
    public let dayWord: String   // "today" | "tomorrow" | "yesterday" | "Mon 21"
    public let offsetText: String // "+9h" | "-5h30m" | "—" when it is the local zone
    public let isWeekend: Bool
    public let vibe: Vibe
    /// Daylight colour where they are. Independent of `vibe`: the dot answers "are they
    /// available" (user's work hours), this answers "is it light out" (fixed day ramp).
    public let sky: RGB
    public let isLocal: Bool
}

/// "Asia/Tokyo" -> "Tokyo", "America/Argentina/Buenos_Aires" -> "Buenos Aires"
public func cityLabel(_ identifier: String) -> String {
    (identifier.split(separator: "/").last.map(String.init) ?? identifier)
        .replacingOccurrences(of: "_", with: " ")
}

private func calendar(_ zone: TimeZone) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = zone
    return cal
}

/// Signed offset of `zone` relative to `local`, at `date` — DST-correct because both
/// sides are evaluated at that instant rather than using a fixed offset.
public func offsetText(_ zone: TimeZone, from local: TimeZone, at date: Date) -> String {
    let delta = zone.secondsFromGMT(for: date) - local.secondsFromGMT(for: date)
    if delta == 0 { return "same" }
    let sign = delta < 0 ? "-" : "+"
    let hours = abs(delta) / 3600
    let minutes = (abs(delta) % 3600) / 60
    return minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours)h\(minutes)m"
}

/// The zone's wall-clock calendar day, re-anchored to UTC midnight so two zones' days
/// can be subtracted exactly. Diffing the real start-of-day instants instead would
/// truncate (a -5h gap reads as 0 days) and mislabel date-line neighbours.
private func dayAnchor(_ zone: TimeZone, at date: Date) -> Date {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let c = calendar(zone).dateComponents([.year, .month, .day], from: date)
    return utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
}

public func dayWord(_ zone: TimeZone, from local: TimeZone, at date: Date) -> String {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let days = utc.dateComponents(
        [.day],
        from: dayAnchor(local, at: date),
        to: dayAnchor(zone, at: date)
    ).day ?? 0
    switch days {
    case 0: return "today"
    case 1: return "tomorrow"
    case -1: return "yesterday"
    default:
        let fmt = DateFormatter()
        fmt.timeZone = zone
        fmt.dateFormat = "EEE d"
        return fmt.string(from: date)
    }
}

public func vibe(hour: Int, hours: Hours = .standard) -> Vibe {
    if inRange(hour, hours.workStart, hours.workEnd) { return .working }
    if inRange(hour, hours.wake, hours.sleep) { return .fringe }
    return .asleep
}

public func zoneInfo(
    for identifier: String,
    at date: Date,
    local: TimeZone,
    hours: Hours = .standard
) -> ZoneInfo? {
    guard let zone = TimeZone(identifier: identifier) else { return nil }
    let cal = calendar(zone)

    let fmt = DateFormatter()
    fmt.timeZone = zone
    fmt.dateFormat = "HH:mm"

    let isLocal = zone.identifier == local.identifier

    return ZoneInfo(
        id: identifier,
        label: cityLabel(identifier),
        time: fmt.string(from: date),
        dayWord: dayWord(zone, from: local, at: date),
        offsetText: isLocal ? "—" : offsetText(zone, from: local, at: date),
        isWeekend: cal.isDateInWeekend(date),
        vibe: vibe(hour: cal.component(.hour, from: date), hours: hours),
        sky: skyTint(
            hour: cal.component(.hour, from: date),
            minute: cal.component(.minute, from: date)
        ),
        isLocal: isLocal
    )
}

/// Candidates for the add-timezone picker. Falls back to all known zones when the query is empty.
public func searchZones(_ query: String) -> [String] {
    let all = TimeZone.knownTimeZoneIdentifiers.sorted()
    let q = query.trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return all }
    return all.filter { $0.localizedCaseInsensitiveContains(q) }
}
