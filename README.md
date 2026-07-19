# Timezone Machine

A macOS menu bar app for reading several timezones at once, without doing the arithmetic.

Click the globe in the menu bar to see your zones side by side. Each row shows the local time
there, its offset from you, whether it's today/tomorrow/yesterday, a weekend marker, and a dot
for whether the person is likely available: green inside work hours, orange awake but off the
clock, gray asleep.

Drag or scroll the hour ruler to simulate a different local time — every row follows, so you can
find a slot that works everywhere. Click the ruler to snap back to now.

Zones are added, removed, and reordered in the popover. Work and waking hours, and the scrub
step, are configurable under the gear.

## Build

Requires macOS 14+ and a Swift toolchain (Command Line Tools are enough — no Xcode needed).

```sh
./run.sh                  # build, bundle as .app, launch
swift run TimezoneCheck   # run the date-math self-check
```
