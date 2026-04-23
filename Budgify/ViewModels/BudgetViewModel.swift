import SwiftData
import Foundation
import UserNotifications

@Observable
final class BudgetViewModel {
    enum BudgetAlertLevel {
        case warning
        case exceeded
    }

    var budgets: [Budget] = []
    private var sentAlertIdentifiers: Set<String> = []

    func add(budget: Budget, context: ModelContext) {
        context.insert(budget)
        try? context.save()
    }

    func update(context: ModelContext) {
        try? context.save()
    }

    func delete(budget: Budget, context: ModelContext) {
        context.delete(budget)
        try? context.save()
    }

    func budget(for month: Date) -> Budget? {
        let calendar = Calendar.current
        return budgets.first {
            calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        }
    }

    func ensureRecurringBudgetForCurrentMonth(context: ModelContext, transactions: [Transaction], rates: [String: Double], now: Date = .now) {
        let calendar = Calendar.current
        let currentMonth = startOfMonth(for: now)
        guard budget(for: currentMonth) == nil else { return }

        guard
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
            let previousBudget = budget(for: previousMonth),
            previousBudget.isRecurringMonthly
        else {
            return
        }

        let rollover: Double
        if previousBudget.rolloverUnusedAmount {
            let spent = expensesTotal(for: previousMonth, in: previousBudget.currency, transactions: transactions, rates: rates)
            rollover = max(previousBudget.limit - spent, 0)
        } else {
            rollover = 0
        }

        let newBudget = Budget(
            month: currentMonth,
            limit: previousBudget.limit + rollover,
            currency: previousBudget.currency,
            name: previousBudget.name,
            isRecurringMonthly: true,
            rolloverUnusedAmount: previousBudget.rolloverUnusedAmount,
            rolloverFromPreviousMonth: rollover
        )

        context.insert(newBudget)
        budgets.append(newBudget)
        try? context.save()
    }

    func alertLevel(for budget: Budget, spent: Double) -> BudgetAlertLevel? {
        guard budget.limit > 0 else { return nil }
        let ratio = spent / budget.limit
        if ratio >= 1 { return .exceeded }
        if ratio >= 0.8 { return .warning }
        return nil
    }

    func alertMessage(for budget: Budget, spent: Double) -> String? {
        guard let level = alertLevel(for: budget, spent: spent) else { return nil }
        switch level {
        case .warning:
            let percent = Int((spent / max(budget.limit, 1)) * 100)
            return "Vous avez atteint \(percent)% de votre budget."
        case .exceeded:
            let over = spent - budget.limit
            return "Budget dépassé de \(String(format: "%.2f", over)) \(budget.currency)."
        }
    }

    func projectedOverrunInDays(for budget: Budget, spent: Double, month: Date, now: Date = .now) -> Int? {
        let calendar = Calendar.current
        guard calendar.isDate(month, equalTo: now, toGranularity: .month) else { return nil }
        guard budget.limit > 0, spent > 0 else { return nil }

        let day = calendar.component(.day, from: now)
        let daysRange = calendar.range(of: .day, in: .month, for: now)
        let daysInMonth = daysRange?.count ?? 30
        guard day > 0 else { return nil }

        let dailyRate = spent / Double(day)
        guard dailyRate > 0 else { return nil }

        let remaining = budget.limit - spent
        if remaining <= 0 { return 0 }

        let daysUntilOverrun = Int(ceil(remaining / dailyRate))
        return day + daysUntilOverrun <= daysInMonth ? daysUntilOverrun : nil
    }

    func notifyIfNeeded(for budget: Budget, spent: Double, month: Date) {
        let calendar = Calendar.current
        guard calendar.isDate(month, equalTo: Date.now, toGranularity: .month) else { return }
        guard let level = alertLevel(for: budget, spent: spent), let body = alertMessage(for: budget, spent: spent) else { return }

        let key = alertIdentifier(for: month, level: level)
        guard !sentAlertIdentifiers.contains(key) else { return }

        let content = UNMutableNotificationContent()
        content.title = level == .exceeded ? "Budget dépassé" : "Alerte budget"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: key, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        sentAlertIdentifiers.insert(key)
    }

    private func alertIdentifier(for month: Date, level: BudgetAlertLevel) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: month)
        let levelKey = level == .warning ? "warning" : "exceeded"
        return "budget-alert-\(monthKey)-\(levelKey)"
    }

    private func expensesTotal(for month: Date, in currency: String, transactions: [Transaction], rates: [String: Double]) -> Double {
        let calendar = Calendar.current
        return transactions
            .filter {
                !$0.isRecurringTemplate &&
                $0.type == .expense &&
                calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            .reduce(0) { partial, transaction in
                partial + converted(amount: transaction.amount, from: transaction.currency, to: currency, rates: rates)
            }
    }

    private func converted(amount: Double, from: String, to: String, rates: [String: Double]) -> Double {
        guard from != to else { return amount }
        if from == "EUR" { return amount * (rates[to] ?? 1) }
        if to == "EUR" { return amount / (rates[from] ?? 1) }
        let inEUR = amount / (rates[from] ?? 1)
        return inEUR * (rates[to] ?? 1)
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
