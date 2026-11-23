import AppKit
import SwiftUI

@main
struct HuixinQuotaApp: App {
    @StateObject private var store: QuotaStore

    init() {
        runCLIArgsIfNeeded()
        let quotaStore = QuotaStore()
        _store = StateObject(wrappedValue: quotaStore)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            BridgeWorker.shutdownAll()
        }
        DispatchQueue.main.async {
            if CommandLine.arguments.contains("--demo") {
                AppWindowHelper.populateDemo(store: quotaStore)
            } else {
                let connectOnStart = CommandLine.arguments.contains("--connect-browsers")
                quotaStore.start(refreshImmediately: !connectOnStart)
                if connectOnStart { quotaStore.connect("workbuddy") }
            }
            if CommandLine.arguments.contains("--show") {
                AppWindowHelper.shared.showWindow(store: quotaStore)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Dashboard(store: store)
                .frame(width: 960, height: 520)
        } label: {
            Image(nsImage: BrandMark.menuBarImage())
        }
        .menuBarExtraStyle(.window)
    }
}
