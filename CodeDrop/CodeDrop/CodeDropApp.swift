import SwiftUI

@main
struct CodeDropApp: App {
    @StateObject private var store = CodeHistoryStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(store)
        } label: {
            if store.isMonitoring {
                Text("📩 \(store.countdownText)")
            } else {
                Image("MenuBarIcon")
                    .renderingMode(.template)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
