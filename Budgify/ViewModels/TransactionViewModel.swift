import SwiftData
import Foundation

@Observable
final class TransactionViewModel {
    var transactions: [Transaction] = []

    func add(transaction: Transaction, context: ModelContext) {
        context.insert(transaction)
        try? context.save()
    }

    func delete(transaction: Transaction, context: ModelContext) {
        context.delete(transaction)
        try? context.save()
    }

    func transactions(for month: Date) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter {
            calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
    }

    func total(type: TransactionType, for month: Date, in currency: String, rates: [String: Double]) -> Double {
        transactions(for: month)
            .filter { $0.type == type }
            .reduce(0) { acc, t in
                acc + converted(amount: t.amount, from: t.currency, to: currency, rates: rates)
            }
    }

    func converted(amount: Double, from: String, to: String, rates: [String: Double]) -> Double {
        if from == to { return amount }
        if to == "THB", let rate = rates["THB"] { return amount * rate }
        if to == "EUR", let rate = rates["THB"] { return amount / rate }
        return amount
    }
}
