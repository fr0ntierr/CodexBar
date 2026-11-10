import CodexBarCore
import Foundation

extension UsageStore {
    func scheduleSupplementalUsageUpdate(
        provider: UsageProvider,
        outcome: ProviderFetchOutcome,
        generation: UInt64?,
        accountID: UUID?)
    {
        guard case let .success(result) = outcome.result else { return }
        self.scheduleSupplementalUsageUpdate(
            provider: provider,
            result: result,
            generation: generation,
            accountID: accountID)
    }

    func scheduleSupplementalUsageUpdates(
        provider: UsageProvider,
        results: [TokenAccountFetchResult],
        selectedAccountID: UUID,
        generation: UInt64?)
    {
        for result in results where result.account.id != selectedAccountID {
            guard case let .success(fetchResult) = result.outcome.result else { continue }
            self.scheduleSupplementalUsageUpdate(
                provider: provider,
                result: fetchResult,
                generation: generation,
                accountID: result.account.id)
        }
    }

    func scheduleSupplementalUsageUpdate(
        provider: UsageProvider,
        result: ProviderFetchResult,
        generation: UInt64?,
        accountID: UUID?)
    {
        guard let sourceTask = result.supplementalUsageTask else { return }

        let expectedUpdatedAt = result.usage.updatedAt
        Task { @MainActor [weak self] in
            let update = await sourceTask.value
            guard let self else { return }
            guard self.isCurrentProviderRefreshGeneration(provider, generation: generation)
            else { return }
            self.applySupplementalUsageUpdate(
                update,
                provider: provider,
                expectedUpdatedAt: expectedUpdatedAt,
                accountID: accountID)
        }
    }

    private func applySupplementalUsageUpdate(
        _ update: ProviderSupplementalUsageUpdate,
        provider: UsageProvider,
        expectedUpdatedAt: Date,
        accountID: UUID?)
    {
    }
}
