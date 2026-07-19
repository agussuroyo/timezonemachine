import SwiftUI
import TimezoneCore

@main
struct TimezoneMachineApp: App {
    init() {
        // Menu bar only: no Dock icon, no app switcher entry.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("Timezone Machine", systemImage: "globe") {
            PopoverView()
        }
        .menuBarExtraStyle(.window)
    }
}
