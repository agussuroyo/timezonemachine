import SwiftUI
import TimezoneCore

private let defaultZones = ["Asia/Tokyo", "Europe/Berlin", "America/New_York"]
private let pxPerHour: CGFloat = 26
private let snapChoices = [1, 5, 10, 15, 30, 60]  // minutes per scrub step

struct PopoverView: View {
    // ponytail: newline-joined ids instead of Codable+JSON — IANA ids contain neither commas nor newlines.
    @AppStorage("zones") private var stored = defaultZones.joined(separator: "\n")
    @State private var offset: TimeInterval = 0
    @AppStorage("snapMinutes") private var snapMinutes = 15
    @AppStorage("wake") private var wake = Hours.standard.wake
    @AppStorage("workStart") private var workStart = Hours.standard.workStart
    @AppStorage("workEnd") private var workEnd = Hours.standard.workEnd
    @AppStorage("sleep") private var sleep = Hours.standard.sleep
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var dragging: String?
    @State private var dragBy: CGFloat = 0
    @State private var rowHeight: CGFloat = 34  // replaced by the measured height on first layout

    private var zones: [String] {
        stored.split(separator: "\n").map(String.init)
    }

    private var hours: Hours {
        Hours(wake: wake, workStart: workStart, workEnd: workEnd, sleep: sleep)
    }

    var body: some View {
        // TimelineView ticks the clock for free and stops when the popover closes — no Timer to own.
        TimelineView(.everyMinute) { context in
            let local = TimeZone.current
            let simulated = context.date.addingTimeInterval(offset)

            VStack(alignment: .leading, spacing: 0) {
                // ponytail: reordering rides a plain DragGesture, not .draggable/.onMove. Those
                // sit on the AppKit drag-session subsystem, which is dead inside a MenuBarExtra
                // window — but ordinary drag *gestures* work here (the ruler scrubs by drag).
                // So this moves the row itself and does the index math, no drag session involved.
                ForEach(zones, id: \.self) { id in
                    if let info = zoneInfo(for: id, at: simulated, local: local, hours: hours) {
                        ZoneRow(info: info, onRemove: { remove(id) })
                        // Measure a real row once; the swap threshold must match actual height.
                        .background(
                            GeometryReader { geo in
                                Color.clear.onAppear { rowHeight = geo.size.height }
                            }
                        )
                        .offset(y: dragging == id ? dragBy : 0)
                        .zIndex(dragging == id ? 1 : 0)
                        .opacity(dragging == id ? 0.9 : 1)
                        .gesture(
                            // minimumDistance keeps clicks on the row's buttons working.
                            DragGesture(minimumDistance: 4)
                                .onChanged { g in
                                    dragging = id
                                    dragBy = g.translation.height
                                    let slots = Int((dragBy / rowHeight).rounded())
                                    guard slots != 0,
                                          let from = zones.firstIndex(of: id),
                                          zones.indices.contains(from + slots) else { return }
                                    move(from, by: slots)
                                    // Rebase so the row stays under the cursor after the swap.
                                    dragBy -= CGFloat(slots) * rowHeight
                                }
                                .onEnded { _ in
                                    dragging = nil
                                    dragBy = 0
                                }
                        )
                    }
                }

                // Local row is always last and never removable or movable.
                if let here = zoneInfo(for: local.identifier, at: simulated, local: local, hours: hours) {
                    ZoneRow(info: here, onRemove: nil)
                }

                Ruler(offset: $offset, simulated: simulated, snap: TimeInterval(snapMinutes * 60))
                    .padding(.top, 10)

                HStack {
                    Button {
                        showAdd.toggle()
                    } label: {
                        Label(showAdd ? "Done" : "Add timezone", systemImage: showAdd ? "checkmark" : "plus")
                    }

                    Spacer()

                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Settings")

                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
                .buttonStyle(.borderless)
                .font(.callout)
                .padding(.top, 10)

                // ponytail: expands inline rather than in a .popover — a popover presented from
                // inside a MenuBarExtra window often never appears or dismisses itself instantly.
                if showAdd {
                    AddZoneView(existing: zones, pick: add)
                        .padding(.top, 8)
                }

                if showSettings {
                    SettingsView(
                        snapMinutes: $snapMinutes,
                        wake: $wake,
                        workStart: $workStart,
                        workEnd: $workEnd,
                        sleep: $sleep
                    )
                    .padding(.top, 8)
                }
            }
            .padding(14)
            .frame(width: 320)
        }
    }

    private func add(_ id: String) {
        guard !zones.contains(id) else { return }
        stored = (zones + [id]).joined(separator: "\n")
        // Panel stays open so several zones can be added in a row; "Done" closes it.
    }

    private func remove(_ id: String) {
        stored = zones.filter { $0 != id }.joined(separator: "\n")
    }

    /// Remove-and-insert rather than swap: a fast drag can cross several slots at once, and
    /// swapping across a gap would leapfrog the rows in between instead of shifting them.
    private func move(_ index: Int, by delta: Int) {
        var next = zones
        let target = index + delta
        guard next.indices.contains(index), next.indices.contains(target) else { return }
        next.insert(next.remove(at: index), at: target)
        stored = next.joined(separator: "\n")
    }
}

private struct SettingsView: View {
    @Binding var snapMinutes: Int
    @Binding var wake: Int
    @Binding var workStart: Int
    @Binding var workEnd: Int
    @Binding var sleep: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Scrub step")
                Spacer()
                Picker("", selection: $snapMinutes) {
                    ForEach(snapChoices, id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            Text("Dot color")
                .font(.caption)
                .foregroundStyle(.secondary)

            hourRow("🟢 Work", $workStart, $workEnd)
            hourRow("🟠 Awake", $wake, $sleep)

            Text("Green inside work hours, orange awake but off-hours, gray asleep.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }

    private func hourRow(_ label: String, _ start: Binding<Int>, _ end: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            hourPicker(start)
            Text("to").foregroundStyle(.secondary)
            hourPicker(end)
        }
    }

    private func hourPicker(_ value: Binding<Int>) -> some View {
        Picker("", selection: value) {
            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
        }
        .labelsHidden()
        .frame(width: 78)
    }
}

private struct ZoneRow: View {
    let info: ZoneInfo
    let onRemove: (() -> Void)?  // nil for the local row, which can't be removed

    private var color: Color {
        switch info.vibe {
        case .working: return .green
        case .fringe: return .orange
        case .asleep: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)

            Text(info.isLocal ? "\(info.label) (you)" : info.label)
                .fontWeight(info.isLocal ? .semibold : .regular)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(info.time)
                .font(.system(.body, design: .monospaced))

            VStack(alignment: .leading, spacing: 0) {
                Text(info.offsetText)
                Text(info.isWeekend ? "\(info.dayWord) · wknd" : info.dayWord)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize()  // two lines of caption; never let the row squeeze them
            .frame(width: 92, alignment: .leading)

            // Always drawn so the row height never shifts; invisible on the local row.
            Button { onRemove?() } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.tertiary)
            .opacity(onRemove == nil ? 0 : 1)
            .disabled(onRemove == nil)
            .help("Remove \(info.label)")
        }
        .padding(.vertical, 4)
        .opacity(info.vibe == .asleep ? 0.6 : 1)
    }
}

/// Hour ticks centred on the simulated time. Drag or scroll to scrub, click to snap back to now.
private struct Ruler: View {
    @Binding var offset: TimeInterval
    let simulated: Date
    let snap: TimeInterval
    @State private var raw: TimeInterval = 0

    var body: some View {
        VStack(spacing: 4) {
            Canvas { ctx, size in
                let mid = size.width / 2
                // Where the current hour boundary sits relative to centre.
                let minutesIntoHour = CGFloat(
                    Calendar.current.component(.minute, from: simulated)
                ) / 60
                let hour = Calendar.current.component(.hour, from: simulated)

                let span = Int(mid / pxPerHour) + 1
                for step in -span...span {
                    let x = mid + (CGFloat(step) - minutesIntoHour) * pxPerHour
                    guard x >= 0, x <= size.width else { continue }
                    let h = (hour + step + 48) % 24
                    let major = h % 6 == 0
                    ctx.stroke(
                        Path { $0.move(to: CGPoint(x: x, y: major ? 6 : 12)); $0.addLine(to: CGPoint(x: x, y: 22)) },
                        with: .color(.secondary.opacity(major ? 0.7 : 0.3))
                    )
                    if major {
                        ctx.draw(
                            Text(String(format: "%02d", h)).font(.system(size: 9)).foregroundStyle(.secondary),
                            at: CGPoint(x: x, y: 0),
                            anchor: .top
                        )
                    }
                }

                // Playhead.
                ctx.stroke(
                    Path { $0.move(to: CGPoint(x: mid, y: 0)); $0.addLine(to: CGPoint(x: mid, y: 26)) },
                    with: .color(.accentColor),
                    lineWidth: 2
                )
            }
            .frame(height: 26)
            .overlay(Scrubber(onScrub: scrub, onReset: reset))

            Text(offset == 0 ? "now · drag or scroll to scrub" : "\(shifted) · click to reset")
                .font(.caption2)
                .foregroundStyle(offset == 0 ? .secondary : .primary)
                .frame(maxWidth: .infinity)
        }
    }

    /// `dx` is raw pointer movement in points. It accumulates unsnapped in `raw`, and only the
    /// exposed `offset` is snapped — snapping every event instead would round each small scroll
    /// tick back to where it started, so slow scrolling would move nothing.
    private func scrub(by dx: CGFloat) {
        raw += Double(dx) / Double(pxPerHour) * 3600
        offset = (raw / snap).rounded() * snap
    }

    private func reset() {
        raw = 0
        offset = 0
    }

    private var shifted: String {
        let mins = Int(abs(offset) / 60)
        let sign = offset < 0 ? "-" : "+"
        return mins % 60 == 0 ? "\(sign)\(mins / 60)h" : "\(sign)\(mins / 60)h\(mins % 60)m"
    }
}

/// All pointer input for the ruler, in one AppKit view laid over the Canvas.
///
/// SwiftUI has no scroll-wheel gesture at all, so the wheel needs an NSView regardless — and
/// an NSView only receives `scrollWheel` if it wins hit-testing, which means it must sit on top
/// and therefore also swallows mouse events. So it handles the drag and the click too, rather
/// than fighting a SwiftUI DragGesture underneath it for the same clicks.
private struct Scrubber: NSViewRepresentable {
    let onScrub: (CGFloat) -> Void
    let onReset: () -> Void

    final class View: NSView {
        var onScrub: ((CGFloat) -> Void)?
        var onReset: (() -> Void)?
        private var dragged = false

        // Everything below reports movement as "how far the content should follow the pointer",
        // so dragging right and swiping right both walk backwards in time.

        override func scrollWheel(with event: NSEvent) {
            // Wheels only report vertical; trackpads report both. Take whichever axis moved more.
            let d = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX : event.scrollingDeltaY
            onScrub?(-d)
        }

        override func mouseDown(with event: NSEvent) { dragged = false }

        override func mouseDragged(with event: NSEvent) {
            dragged = true
            onScrub?(-event.deltaX)
        }

        override func mouseUp(with event: NSEvent) {
            if !dragged { onReset?() }
        }

        // Scrub without having to focus the popover window first.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }
    }

    func makeNSView(context: Context) -> View {
        let v = View()
        v.onScrub = onScrub
        v.onReset = onReset
        return v
    }

    func updateNSView(_ v: View, context: Context) {
        v.onScrub = onScrub
        v.onReset = onReset
    }
}

private struct AddZoneView: View {
    let existing: [String]
    let pick: (String) -> Void
    @State private var query = ""

    private var matches: [String] {
        searchZones(query).filter { !existing.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            TextField("Search city or region", text: $query)
                .textFieldStyle(.roundedBorder)

            if matches.isEmpty {
                Text("No timezone matches “\(query)”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(matches, id: \.self) { id in
                            Button {
                                pick(id)
                            } label: {
                                HStack {
                                    Text(cityLabel(id))
                                    Spacer()
                                    Text(id).font(.caption).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
