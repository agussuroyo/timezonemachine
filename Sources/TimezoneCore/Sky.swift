import Foundation

/// A plain colour triple, so this module stays free of any UI framework.
public struct RGB: Sendable, Equatable {
    public let r, g, b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Sky colour through the day, as (hour, colour) keyframes on a 24-hour circle.
/// The final stop repeats the first so midnight does not seam.
///
/// ponytail: a fixed hour ramp, not real solar position. IANA identifiers carry no
/// coordinates, so true sunrise — which moves with latitude and season — is not derivable
/// from what we have. Upgrade path if it ever matters: a lat/long table plus a
/// solar-elevation calculation.
private let stops: [(hour: Double, color: RGB)] = [
    (0.0, RGB(0.09, 0.11, 0.26)),   // deep night
    (4.5, RGB(0.11, 0.13, 0.30)),   // late night
    (6.0, RGB(0.35, 0.25, 0.45)),   // pre-dawn violet
    (7.0, RGB(0.85, 0.48, 0.38)),   // dawn coral
    (8.5, RGB(0.98, 0.82, 0.55)),   // morning gold
    (12.0, RGB(1.00, 0.93, 0.72)),  // noon
    (16.0, RGB(0.99, 0.87, 0.62)),  // afternoon
    (18.0, RGB(0.95, 0.58, 0.32)),  // dusk amber
    (19.5, RGB(0.62, 0.32, 0.42)),  // sunset rose
    (21.0, RGB(0.20, 0.17, 0.36)),  // night falls
    (24.0, RGB(0.09, 0.11, 0.26)),  // == 0.0, closes the circle
]

/// Sky colour at a wall-clock time, linearly interpolated between the keyframes.
public func skyTint(hour: Int, minute: Int = 0) -> RGB {
    let t = min(max(Double(hour) + Double(minute) / 60, 0), 24)

    // Small fixed table — a linear scan is cheaper than the arithmetic to avoid one.
    for i in 1..<stops.count where t <= stops[i].hour {
        let (h0, c0) = stops[i - 1]
        let (h1, c1) = stops[i]
        let span = h1 - h0
        let f = span == 0 ? 0 : (t - h0) / span
        return RGB(
            c0.r + (c1.r - c0.r) * f,
            c0.g + (c1.g - c0.g) * f,
            c0.b + (c1.b - c0.b) * f
        )
    }
    return stops[stops.count - 1].color
}
