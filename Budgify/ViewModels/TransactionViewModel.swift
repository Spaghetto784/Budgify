import SwiftData
import Foundation

@Observable
final class TransactionViewModel {
    var transactions: [Transaction] = []

    func add(transaction: Transaction, context: ModelContext) {
        context.insert(transaction)
        try? context.save()
    }

    func addRecurringTemplate(from transaction: Transaction, frequency: RecurrenceFrequency, context: ModelContext) {
        let seriesID = UUID().uuidString
        let template = Transaction(
            title: transaction.title,
            amount: transaction.amount,
            date: transaction.date,
            currency: transaction.currency,
            type: transaction.type,
            category: nil,
            categoryNameSnapshot: transaction.categoryNameSnapshot,
            categoryIconSnapshot: transaction.categoryIconSnapshot,
            categoryColorHexSnapshot: transaction.categoryColorHexSnapshot,
            note: transaction.note,
            noteCiphertext: transaction.noteCiphertext,
            noteHash: transaction.noteHash,
            recurrenceFrequencyRaw: frequency.rawValue,
            recurrenceNextDate: nextDate(after: transaction.date, frequency: frequency),
            recurrenceSeriesID: seriesID,
            isRecurringTemplate: true
        )
        context.insert(template)
        try? context.save()
    }

    func generateDueRecurringTransactions(context: ModelContext, now: Date = .now) {
        let templates = transactions.filter { $0.isRecurringTemplate }
        guard !templates.isEmpty else { return }

        for template in templates {
            guard let frequency = template.recurrenceFrequency else { continue }
            var dueDate = template.recurrenceNextDate ?? template.date

            while dueDate <= now {
                let occurrence = Transaction(
                    title: template.title,
                    amount: template.amount,
                    date: dueDate,
                    currency: template.currency,
                    type: template.type,
                    category: nil,
                    categoryNameSnapshot: template.categoryNameSnapshot,
                    categoryIconSnapshot: template.categoryIconSnapshot,
                    categoryColorHexSnapshot: template.categoryColorHexSnapshot,
                    note: template.note,
                    noteCiphertext: template.noteCiphertext,
                    noteHash: template.noteHash,
                    recurrenceSeriesID: template.recurrenceSeriesID,
                    isRecurringTemplate: false
                )
                context.insert(occurrence)
                dueDate = nextDate(after: dueDate, frequency: frequency)
            }

            template.recurrenceNextDate = dueDate
        }

        try? context.save()
    }

    func delete(transaction: Transaction, context: ModelContext) {
        context.delete(transaction)
        try? context.save()
    }

    func detachCategoryRelations(context: ModelContext) {
        if let transactions = try? context.fetch(FetchDescriptor<Transaction>()) {
            for transaction in transactions {
                transaction.category = nil
            }
            try? context.save()
        }
    }

    func transactions(for month: Date) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter {
            !$0.isRecurringTemplate &&
            calendar.isDate($0.date, equalTo: month, toGranularity: .month)
        }
    }

    func transactions(from startDate: Date, to endDate: Date) -> [Transaction] {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        return transactions.filter {
            !$0.isRecurringTemplate &&
            $0.date >= startDate && $0.date <= endOfDay
        }
    }

    func total(type: TransactionType, for month: Date, in currency: String, rates: [String: Double]) -> Double {
        transactions(for: month)
            .filter { $0.type == type }
            .reduce(0) { acc, t in
                acc + converted(amount: t.amount, from: t.currency, to: currency, rates: rates)
            }
    }

    func total(type: TransactionType, from startDate: Date, to endDate: Date, in currency: String, rates: [String: Double]) -> Double {
        transactions(from: startDate, to: endDate)
            .filter { $0.type == type }
            .reduce(0) { acc, t in
                acc + converted(amount: t.amount, from: t.currency, to: currency, rates: rates)
            }
    }

    func converted(amount: Double, from: String, to: String, rates: [String: Double]) -> Double {
        guard from != to else { return amount }
        if from == "EUR" { return amount * (rates[to] ?? 1) }
        if to == "EUR" { return amount / (rates[from] ?? 1) }
        let inEUR = amount / (rates[from] ?? 1)
        return inEUR * (rates[to] ?? 1)
    }

    private func nextDate(after date: Date, frequency: RecurrenceFrequency) -> Date {
        let calendar = Calendar.current
        let component: Calendar.Component = frequency == .weekly ? .day : .month
        let value = frequency == .weekly ? 7 : 1
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }
}
