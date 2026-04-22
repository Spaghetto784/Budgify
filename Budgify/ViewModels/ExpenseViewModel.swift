import SwiftData
import Foundation

@Observable
final class ExpenseViewModel {
    var expenses: [Expense] = []
    var selectedCurrency: String = "EUR"

    func add(expense: Expense, context: ModelContext) {
        context.insert(expense)
        try? context.save()
    }

    func delete(expense: Expense, context: ModelContext) {
        context.delete(expense)
        try? context.save()
    }

    func total(in currency: String, rates: [String: Double]) -> Double {
        expenses.reduce(0) { acc, e in
            if e.currency == currency {
                return acc + e.amount
            }
            if currency == "EUR", let rate = rates["THB"] {
                return acc + (e.amount / rate)
            }
            if currency == "THB", let rate = rates["THB"] {
                return acc + (e.amount * rate)
            }
            return acc
        }
    }

    func expenses(for category: Category) -> [Expense] {
        expenses.filter { $0.category.name == category.name }
    }

    func expenses(for month: Date) -> [Expense] {
        let calendar = Calendar.current
        return expenses.filter {
            calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
    }
}
