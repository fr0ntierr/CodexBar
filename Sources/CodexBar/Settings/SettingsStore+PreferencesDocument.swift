import CodexBarCore
import Foundation

extension SettingsStore {
    func exportPreferences() throws -> PreferencesDocument {
        var document = PreferencesDocument()
        try document.include(self.syncedPreferences)
        try document.set("limitResetNotificationsEnabled", self.limitResetNotificationsEnabled)
        try document.set("codexResetCreditExpiryNotificationsEnabled", self.codexResetCreditExpiryNotificationsEnabled)
        try document.set("upcomingResetNotificationsEnabled", self.upcomingResetNotificationsEnabled)
        try document.set("mergeIcons", self.mergeIcons)
        try document.set("mergeIconsStacked", self.mergeIconsStacked)
        try document.set("switcherShowsIcons", self.switcherShowsIcons)
        try document.set("menuBarColorByProvider", self.menuBarColorByProvider)
        try document.set("mergedOverviewLayout", self.mergedOverviewLayout.rawValue)
        if self.userDefaults.object(forKey: "mergedOverviewSelectedProviders") != nil {
            let active = self.orderedProviders().filter { self.providerEnablement[$0] ?? false }
            try document.set(
                "mergedOverviewSelectedProviders",
                self.resolvedMergedOverviewProviders(activeProviders: active)
                    .map(\.rawValue))
        }
        try document.set("switcherShortcuts", self.providerSwitcherShortcuts)
        return document
    }

    func importPreferences(_ document: PreferencesDocument) throws {
        try document.validate()
        let synced = try document.applying(to: self.syncedPreferences)
        // Use the normal setters. CloudKit alone owns its incoming-record echo-suppression baseline.
        let consent = self.adaptiveActivityScanConsent
        self.applySyncedPreferences(synced)
        if self.adaptiveActivityScanConsent != consent { self.adaptiveActivityScanConsent = consent }
        if let value: Bool = try document.value("limitResetNotificationsEnabled") {
            self.limitResetNotificationsEnabled = value
        }
        if let value: Bool = try document.value("codexResetCreditExpiryNotificationsEnabled") {
            self.codexResetCreditExpiryNotificationsEnabled = value
        }
        if let value: Bool = try document.value("upcomingResetNotificationsEnabled") {
            self.upcomingResetNotificationsEnabled = value
        }
        if let value: Bool = try document.value("mergeIcons") { self.mergeIcons = value }
        if let value: Bool = try document.value("mergeIconsStacked") { self.mergeIconsStacked = value }
        if let value: Bool = try document.value("switcherShowsIcons") { self.switcherShowsIcons = value }
        if let value: Bool = try document.value("menuBarColorByProvider") { self.menuBarColorByProvider = value }
        if let value: String = try document.value("mergedOverviewLayout"),
           let layout = MergedOverviewLayout(rawValue: value)
        {
            self.mergedOverviewLayout = layout
        }
        if let value: [String] = try document.value("mergedOverviewSelectedProviders") {
            self.mergedOverviewSelectedProviders = value.compactMap(ProviderInstanceID.init(rawValue:))
            let active = self.orderedProviders().filter { self.providerEnablement[$0] ?? false }
            self.userDefaults.set(
                active.map(\.rawValue).sorted(),
                forKey: Self.mergedOverviewSelectionEditedActiveProvidersKey)
        }
        if let value: [String: String] = try document.value("switcherShortcuts") {
            try self.setProviderSwitcherShortcuts(value)
        }
    }

    func setProviderSwitcherShortcuts(_ shortcuts: [String: String]) throws {
        let validated = try ProviderSwitcherShortcuts.validated(shortcuts)
        self.providerSwitcherShortcuts = validated
        self.userDefaults.set(validated, forKey: "switcherShortcuts")
    }

    func consumePendingPreferencesImport() {
        self.userDefaults.synchronize()
        guard let data = self.userDefaults.data(forKey: PreferencesDocument.pendingImportKey) else { return }
        do {
            try self.importPreferences(PreferencesDocument(data: data))
            if self.userDefaults.data(forKey: PreferencesDocument.pendingImportKey) == data {
                self.userDefaults.removeObject(forKey: PreferencesDocument.pendingImportKey)
                self.userDefaults.synchronize()
            }
        } catch {
            CodexBarLog.logger(LogCategories.settings).error("Could not import portable preferences: \(error)")
        }
    }

    var syncedPreferences: SyncedPreferences {
        SyncedPreferences(
            statusChecksEnabled: self.statusChecksEnabled,
            sessionQuotaNotificationsEnabled: false,
            quotaWarningNotificationsEnabled: false,
            predictivePaceWarningNotificationsEnabled: false,
            quotaWarningThresholds: self.quotaWarningThresholds,
            quotaWarningSessionThresholds: self.quotaWarningThresholds(.session),
            quotaWarningWeeklyThresholds: self.quotaWarningThresholds(.weekly),
            quotaWarningSessionEnabled: self.quotaWarningWindowEnabled(.session),
            quotaWarningWeeklyEnabled: self.quotaWarningWindowEnabled(.weekly),
            quotaWarningSoundEnabled: false,
            quotaWarningOnScreenAlertEnabled: false,
            quotaWarningMarkersVisible: self.quotaWarningMarkersVisible,
            paceVisible: self.paceVisible,
            weeklyProgressWorkDays: self.weeklyProgressWorkDays,
            workdayTickAppearance: self.workdayTickAppearance.rawValue,
            usageBarsShowUsed: self.usageBarsShowUsed,
            resetTimesShowAbsolute: self.resetTimesShowAbsolute,
            costUsageEnabled: self.costUsageEnabled,
            costComparisonPeriodsEnabled: self.costComparisonPeriodsEnabled,
            costSummaryDisplayStyle: self.costSummaryDisplayStyleRaw,
            hidePersonalInfo: self.hidePersonalInfo,
            randomBlinkEnabled: self.randomBlinkEnabled,
            confettiOnSessionLimitResetsEnabled: self.confettiOnSessionLimitResetsEnabled,
            confettiOnWeeklyLimitResetsEnabled: self.confettiOnWeeklyLimitResetsEnabled,
            menuBarShowsHighestUsage: self.menuBarShowsHighestUsage,
            unifiedIconSource: self.unifiedIconSource.rawValue,
            showOptionalCreditsAndExtraUsage: self.showOptionalCreditsAndExtraUsage,
            providerChangelogLinksEnabled: self.providerChangelogLinksEnabled,
            preferredCurrencyCode: self.preferredCurrencyCode,
            providersSortedAlphabetically: self.providersSortedAlphabetically,
            refreshFrequency: self.refreshFrequency.rawValue,
            refreshAllProvidersOnMenuOpen: self.refreshAllProvidersOnMenuOpen)
    }

    func applySyncedPreferences(_ preferences: SyncedPreferences) {
        self.statusChecksEnabled = preferences.statusChecksEnabled
        self.quotaWarningThresholds = preferences.quotaWarningThresholds
        self.setQuotaWarningThresholds(.session, thresholds: preferences.quotaWarningSessionThresholds)
        self.setQuotaWarningThresholds(.weekly, thresholds: preferences.quotaWarningWeeklyThresholds)
        self.setQuotaWarningWindowEnabled(.session, enabled: preferences.quotaWarningSessionEnabled)
        self.setQuotaWarningWindowEnabled(.weekly, enabled: preferences.quotaWarningWeeklyEnabled)
        self.quotaWarningMarkersVisible = preferences.quotaWarningMarkersVisible
        if let paceVisible = preferences.paceVisible {
            self.paceVisible = paceVisible
        }
        self.weeklyProgressWorkDays = preferences.weeklyProgressWorkDays
        if let rawAppearance = preferences.workdayTickAppearance,
           let appearance = WorkdayTickAppearance(rawValue: rawAppearance)
        {
            self.workdayTickAppearance = appearance
        }
        self.usageBarsShowUsed = preferences.usageBarsShowUsed
        self.resetTimesShowAbsolute = preferences.resetTimesShowAbsolute
        self.costUsageEnabled = preferences.costUsageEnabled
        self.costComparisonPeriodsEnabled = preferences.costComparisonPeriodsEnabled
        self.costSummaryDisplayStyleRaw = preferences.costSummaryDisplayStyle
        self.hidePersonalInfo = preferences.hidePersonalInfo
        self.randomBlinkEnabled = preferences.randomBlinkEnabled
        self.confettiOnSessionLimitResetsEnabled = preferences.confettiOnSessionLimitResetsEnabled
        self.confettiOnWeeklyLimitResetsEnabled = preferences.confettiOnWeeklyLimitResetsEnabled
        self.unifiedIconSource = preferences.unifiedIconSource.flatMap(UnifiedIconSource.init(rawValue:))
            ?? (preferences.menuBarShowsHighestUsage ? .highestUsage : .currentSelection)
        self.showOptionalCreditsAndExtraUsage = preferences.showOptionalCreditsAndExtraUsage
        self.providerChangelogLinksEnabled = preferences.providerChangelogLinksEnabled
        self.preferredCurrencyCode = preferences.preferredCurrencyCode
        self.providersSortedAlphabetically = preferences.providersSortedAlphabetically
        if let refreshFrequency = RefreshFrequency(rawValue: preferences.refreshFrequency) {
            self.refreshFrequency = refreshFrequency
        }
        self.refreshAllProvidersOnMenuOpen = preferences.refreshAllProvidersOnMenuOpen
    }
}
