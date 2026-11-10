import CodexBarCore
import Foundation

extension Notification.Name {
    static let codexbarDebugBlinkNow = Notification.Name("codexbarDebugBlinkNow")
    #if DEBUG
    static let codexbarDebugSimulateMemoryPressure =
        Notification.Name("com.steipete.codexbarlite.debug.simulateMemoryPressure")
    #endif
    static let codexbarSessionLimitReset = Notification.Name("codexbarSessionLimitReset")
    static let codexbarWeeklyLimitReset = Notification.Name("codexbarWeeklyLimitReset")
    static let codexbarProviderConfigDidChange = Notification.Name("codexbarProviderConfigDidChange")
    static let codexbarLocalConfigFileDidChange = Notification.Name("codexbarLocalConfigFileDidChange")
}

@MainActor
final class SessionLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}

@MainActor
final class WeeklyLimitResetEvent: NSObject {
    let provider: UsageProvider
    let accountIdentifier: String
    let accountLabel: String?
    let usedPercent: Double

    init(provider: UsageProvider, accountIdentifier: String, accountLabel: String?, usedPercent: Double) {
        self.provider = provider
        self.accountIdentifier = accountIdentifier
        self.accountLabel = accountLabel
        self.usedPercent = usedPercent
    }
}
