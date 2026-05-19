import SwiftData
import Foundation

struct SubscriptionInsight: Identifiable {
    let id: String
    let title: String
    let monthlyEstimate: Double
    let annualEstimate: Double
    let currency: String
    let occurrences: Int
}

private struct DeletedTransactionSnapshot {
    let title: String
    let amount: Double
    let date: Date
    let currency: String
    let type: TransactionType
    let categoryNameSnapshot: String?
    let categoryIconSnapshot: String?
    let categoryColorHexSnapshot: String?
    let note: String
    let noteCiphertext: String?
    let noteHash: String?
    let recurrenceFrequencyRaw: String?
    let recurrenceNextDate: Date?
    let recurrenceSeriesID: String?
    let isRecurringTemplate: Bool
    let excludedFromBudget: Bool
    let tagsRaw: String
    let splitGroupID: String?
}

@Observable
final class TransactionViewModel {
    var transactions: [Transaction] = []
    private var lastDeletedTransaction: DeletedTransactionSnapshot?

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
            isRecurringTemplate: true,
            excludedFromBudget: transaction.excludedFromBudget
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
                    isRecurringTemplate: false,
                    excludedFromBudget: template.excludedFromBudget
                )
                context.insert(occurrence)
                dueDate = nextDate(after: dueDate, frequency: frequency)
            }

            template.recurrenceNextDate = dueDate
        }

        try? context.save()
    }

    func delete(transaction: Transaction, context: ModelContext) {
        lastDeletedTransaction = DeletedTransactionSnapshot(
            title: transaction.title,
            amount: transaction.amount,
            date: transaction.date,
            currency: transaction.currency,
            type: transaction.type,
            categoryNameSnapshot: transaction.categoryNameSnapshot,
            categoryIconSnapshot: transaction.categoryIconSnapshot,
            categoryColorHexSnapshot: transaction.categoryColorHexSnapshot,
            note: transaction.note,
            noteCiphertext: transaction.noteCiphertext,
            noteHash: transaction.noteHash,
            recurrenceFrequencyRaw: transaction.recurrenceFrequencyRaw,
            recurrenceNextDate: transaction.recurrenceNextDate,
            recurrenceSeriesID: transaction.recurrenceSeriesID,
            isRecurringTemplate: transaction.isRecurringTemplate,
            excludedFromBudget: transaction.excludedFromBudget,
            tagsRaw: transaction.tagsRaw,
            splitGroupID: transaction.splitGroupID
        )
        context.delete(transaction)
        try? context.save()
    }

    var canUndoDelete: Bool {
        lastDeletedTransaction != nil
    }

    func undoLastDelete(context: ModelContext) {
        guard let snapshot = lastDeletedTransaction else { return }
        let restored = Transaction(
            title: snapshot.title,
            amount: snapshot.amount,
            date: snapshot.date,
            currency: snapshot.currency,
            type: snapshot.type,
            category: nil,
            categoryNameSnapshot: snapshot.categoryNameSnapshot,
            categoryIconSnapshot: snapshot.categoryIconSnapshot,
            categoryColorHexSnapshot: snapshot.categoryColorHexSnapshot,
            note: snapshot.note,
            noteCiphertext: snapshot.noteCiphertext,
            noteHash: snapshot.noteHash,
            recurrenceFrequencyRaw: snapshot.recurrenceFrequencyRaw,
            recurrenceNextDate: snapshot.recurrenceNextDate,
            recurrenceSeriesID: snapshot.recurrenceSeriesID,
            isRecurringTemplate: snapshot.isRecurringTemplate,
            excludedFromBudget: snapshot.excludedFromBudget,
            tagsRaw: snapshot.tagsRaw,
            splitGroupID: snapshot.splitGroupID
        )
        context.insert(restored)
        try? context.save()
        lastDeletedTransaction = nil
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

    func subscriptionInsights(for month: Date, in currency: String, rates: [String: Double]) -> [SubscriptionInsight] {
        let calendar = Calendar.current
        guard let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: month) else { return [] }
        let candidates = transactions.filter {
            !$0.isRecurringTemplate &&
            $0.type == .expense &&
            !$0.excludedFromBudget &&
            $0.date >= sixMonthsAgo &&
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let grouped = Dictionary(grouping: candidates, by: { normalizeSubscriptionTitle($0.title) })
        return grouped.compactMap { key, values in
            guard values.count >= 2 else { return nil }
            let sorted = values.sorted { $0.date < $1.date }
            guard
                let first = sorted.first?.date,
                let last = sorted.last?.date,
                let days = calendar.dateComponents([.day], from: first, to: last).day,
                days >= 25
            else { return nil }

            let total = sorted.reduce(0.0) { acc, transaction in
                acc + converted(amount: transaction.amount, from: transaction.currency, to: currency, rates: rates)
            }
            let monthsCovered = max(Double(days) / 30.0, 1.0)
            let monthly = total / monthsCovered
            return SubscriptionInsight(
                id: key,
                title: key.capitalized,
                monthlyEstimate: monthly,
                annualEstimate: monthly * 12.0,
                currency: currency,
                occurrences: values.count
            )
        }
        .sorted { $0.monthlyEstimate > $1.monthlyEstimate }
    }

    private func nextDate(after date: Date, frequency: RecurrenceFrequency) -> Date {
        let calendar = Calendar.current
        let component: Calendar.Component = frequency == .weekly ? .day : .month
        let value = frequency == .weekly ? 7 : 1
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }

    private func normalizeSubscriptionTitle(_ title: String) -> String {
        title
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
