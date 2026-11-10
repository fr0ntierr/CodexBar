import CodexBarCore

extension StatusItemController {
    nonisolated static func switcherWeeklyMetricPercent(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        showUsed: Bool,
        preference: MenuBarMetricPreference = .automatic) -> Double?
    {
        let metric = preference == .automatic || preference == .monthlyPlan
            ? MenuBarMetricWindowResolver.rateWindow(
                preference: preference,
                provider: provider,
                snapshot: snapshot,
                supportsAverage: false)
            : nil
        let presentation = ProviderDescriptorRegistry.descriptor(for: provider).presentation
        let window: RateWindow? = if preference == .monthlyPlan {
            metric
        } else if preference == .automatic,
                  let metric,
                  presentation.switcherUsesAutomaticMenuBarWindow
                  || (presentation.automaticSelectionPrioritizesExhaustedWindow && metric.usedPercent >= 100)
        {
            metric
        } else {
            snapshot?.switcherWeeklyWindow(for: provider, showUsed: showUsed)
        }
        // Provider-specific by design: Claude's enterprise/extra-usage spend limit can be its only real metric.
        let displayWindow: RateWindow? = if let window, !window.isSyntheticPlaceholder {
            window
        } else if provider == .claude,
                  let snapshot,
                  let spendWindow = MenuBarMetricWindowResolver.claudeSpendLimitWindow(snapshot: snapshot),
                  snapshot.providerCost?.used.isFinite == true,
                  snapshot.providerCost?.limit.isFinite == true,
                  spendWindow.usedPercent.isFinite
        {
            spendWindow
        } else {
            window
        }
        if let displayWindow {
            return showUsed ? displayWindow.usedPercent : displayWindow.remainingPercent
        }
        guard preference == .automatic,
              let snapshot,
              let usedPercent = presentation.fallbackSwitcherUsedPercent(snapshot: snapshot),
              usedPercent.isFinite else { return nil }
        return showUsed ? usedPercent : max(0, 100 - usedPercent)
    }
}
