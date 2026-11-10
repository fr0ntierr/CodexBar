import AppKit
import CodexBarCore
import Foundation

enum MenuBarUsageSource {
    case local(UsageSnapshot?)

    var snapshot: UsageSnapshot? {
        switch self {
        case let .local(snapshot): snapshot
        }
    }

    var isFleet: Bool { false }
}

extension StatusItemController {
    func menuBarUsageSource(for provider: UsageProvider) -> MenuBarUsageSource {
        .local(self.store.menuBarSnapshot(for: provider.instanceID))
    }

    func menuBarIsStale(for provider: UsageProvider) -> Bool {
        self.store.isStale(provider: provider)
    }

    func isRefreshingLocalMenuBarUsage(_ provider: UsageProvider) -> Bool {
        self.store.refreshingProviders.contains(provider.instanceID)
    }

    func updateMenuBarSourceDescription(for button: NSButton, providers: [UsageProvider]) {
        button.setAccessibilityHelp(nil)
    }

    func menuBarLayoutWindows(
        provider: UsageProvider,
        snapshot: UsageSnapshot?,
        now: Date) -> MenuBarLayoutWindows
    {
        self.store.menuBarLayoutWindows(
            provider: provider,
            snapshot: snapshot,
            includeLocalDerivedData: true,
            now: now)
    }
}
