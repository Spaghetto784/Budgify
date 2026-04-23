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

    func totalWorth(in currency: String, rates: [String: Double]) -> Double {
        accounts.reduce(0) { acc, account in
            if account.currency == currency { return acc + account.balance }
            if currency == "THB", let rate = rates["THB"] { return acc + account.balance * rate }
            if currency == "EUR", let rate = rates["THB"] { return acc + account.balance / rate }
            return acc
        }
    }
}
