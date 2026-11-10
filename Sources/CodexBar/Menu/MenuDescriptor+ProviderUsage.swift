import CodexBarCore
import Foundation

extension MenuDescriptor {
    static func appendOpenAIAPIUsageSummary(
        entries: inout [Entry],
        usage: OpenAIAPIUsageSnapshot,
        preferredCurrencyCode: String = "auto")
    {
        let today = usage.currentDay
        let last7 = usage.last7Days
        let last30 = usage.last30Days
        let historyLabel = usage.historyWindowLabel
        let todayCost = UsageFormatter.convertedCostString(
            today.costUSD, preferredCurrency: preferredCurrencyCode, providerCurrency: "USD")
        let last7Cost = UsageFormatter.convertedCostString(
            last7.costUSD, preferredCurrency: preferredCurrencyCode, providerCurrency: "USD")
        let last30Cost = UsageFormatter.convertedCostString(
            last30.costUSD, preferredCurrency: preferredCurrencyCode, providerCurrency: "USD")

        entries.append(.text(
            "\(L("Today")): \(todayCost) · " +
                "\(UsageFormatter.tokenCountString(today.totalTokens)) \(L("tokens"))",
            .secondary))
        entries.append(.text(
            "7d: \(last7Cost) · " +
                "\(UsageFormatter.tokenCountString(last7.requests)) \(L("requests"))",
            .secondary))
        entries.append(.text(
            "\(historyLabel): \(last30Cost) · " +
                "\(UsageFormatter.tokenCountString(last30.requests)) \(L("requests"))",
            .secondary))
        if let topModel = usage.topModels.first?.name {
            entries.append(.text("\(L("Top model")): \(topModel)", .secondary))
        }
    }
}
