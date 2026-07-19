import Foundation

/// How far the ruler may be scrubbed from now, in either direction.
/// Enough for "same time next weekday", short of wandering days away by accident.
public let maxShift: TimeInterval = 48 * 3600

/// Turns a raw, unsnapped scrub distance into the pair the ruler holds.
///
/// `raw` is clamped too, not just the returned offset. If only the offset were bounded,
/// scrolling hard against the limit would silently pile up raw distance that has to be
/// unwound before movement resumes — the ruler would feel stuck.
///
/// Every path that moves the ruler (scroll, drag, step, reset) goes through here, so the
/// bound cannot disagree between input methods.
public func clampedOffset(
    raw: TimeInterval,
    snap: TimeInterval,
    limit: TimeInterval = maxShift
) -> (raw: TimeInterval, offset: TimeInterval) {
    let bounded = min(max(raw, -limit), limit)
    guard snap > 0 else { return (bounded, bounded) }
    return (bounded, (bounded / snap).rounded() * snap)
}
