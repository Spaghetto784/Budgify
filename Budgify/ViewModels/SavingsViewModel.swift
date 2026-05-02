import SwiftData
import Foundation

@Observable
final class SavingsViewModel {
    var accounts: [SavingsAccount] = []
    var goals: [SavingsGoal] = []

    func addAccount(account: SavingsAccount, context: ModelContext) {
        context.insert(account)
        try? context.save()
    }

    func deleteAccount(account: SavingsAccount, context: ModelContext) {
        context.delete(account)
        try? context.save()
    }

    func updateBalance(account: SavingsAccount, newBalance: Double, note: String, context: ModelContext) {
        let entry = SavingsEntry(balance: newBalance, note: note)
        context.insert(entry)
        account.history.append(entry)
        account.balance = newBalance
        try? context.save()
    }

    func transfer(
        from source: SavingsAccount,
        to destination: SavingsAccount,
        amount: Double,
        currencyService: CurrencyService,
        context: ModelContext
    ) {
        guard amount > 0, source.id != destination.id else { return }
        let sourceAmount = amount
        let destinationAmount = currencyService.convert(amount: amount, from: source.currency, to: destination.currency)

        let sourceNewBalance = source.balance - sourceAmount
        let destinationNewBalance = destination.balance + destinationAmount

        updateBalance(
            account: source,
            newBalance: sourceNewBalance,
            note: "Virement vers \(destination.name): -\(sourceAmount.formatted(.number.precision(.fractionLength(2)))) \(source.currency)",
            context: context
        )
        updateBalance(
            account: destination,
            newBalance: destinationNewBalance,
            note: "Virement depuis \(source.name): +\(destinationAmount.formatted(.number.precision(.fractionLength(2)))) \(destination.currency)",
            context: context
        )
    }

    func addGoal(goal: SavingsGoal, context: ModelContext) {
        context.insert(goal)
        try? context.save()
    }

    func deleteGoal(goal: SavingsGoal, context: ModelContext) {
        context.delete(goal)
        try? context.save()
    }

    func updateGoal(goal: SavingsGoal, amount: Double, context: ModelContext) {
        goal.current = amount
        try? context.save()
    }

    func recommendedWeeklyContribution(for goal: SavingsGoal, from referenceDate: Date = .now) -> Double? {
        guard let deadline = goal.deadline else { return nil }
        let remaining = max(goal.target - goal.current, 0)
        guard remaining > 0 else { return 0 }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: deadline)
        guard let days = calendar.dateComponents([.day], from: start, to: end).day, days > 0 else { return nil }

        let weeks = max(Double(days) / 7.0, 1)
        return remaining / weeks
    }

    func totalWorth(in currency: String, rates: [String: Double]) -> Double {
        accounts.reduce(0) { acc, account in
            if account.currency == currency { return acc + account.balance }
            if currency == "THB", let rate = rates["THB"] { return acc + account.balance * rate }
            if currency == "EUR", let rate = rates["THB"] { return acc + account.balance / rate }
            return acc
        }
    }
}
