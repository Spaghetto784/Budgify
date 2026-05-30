import SwiftData
import Foundation

enum TransactionType: String, Codable {
    case expense
    case income
    case loan
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case weekly
    case monthly
}

@Model
final class Transaction {
    var title: String
    var amount: Double
    var date: Date
    var currency: String
    var type: TransactionType
    var category: Category?
    var categoryNameSnapshot: String?
    var categoryIconSnapshot: String?
    var categoryColorHexSnapshot: String?
    var note: String
    var noteCiphertext: String?
    var noteHash: String?
    var recurrenceFrequencyRaw: String?
    var recurrenceNextDate: Date?
    var recurrenceSeriesID: String?
    var isRecurringTemplate: Bool
    var excludedFromBudget: Bool
    var tagsRaw: String
    var splitGroupID: String?
    var splitsRaw: String

    init(
        title: String,
        amount: Double,
        date: Date = .now,
        currency: String = "EUR",
        type: TransactionType,
        category: Category? = nil,
        categoryNameSnapshot: String? = nil,
        categoryIconSnapshot: String? = nil,
        categoryColorHexSnapshot: String? = nil,
        note: String = "",
        noteCiphertext: String? = nil,
        noteHash: String? = nil,
        recurrenceFrequencyRaw: String? = nil,
        recurrenceNextDate: Date? = nil,
        recurrenceSeriesID: String? = nil,
        isRecurringTemplate: Bool = false,
        excludedFromBudget: Bool = false,
        tagsRaw: String = "",
        splitGroupID: String? = nil,
        splitsRaw: String = ""
    ) {
        self.title = title
        self.amount = amount
        self.date = date
        self.currency = currency
        self.type = type
        self.category = category
        self.categoryNameSnapshot = categoryNameSnapshot ?? category?.name
        self.categoryIconSnapshot = categoryIconSnapshot ?? category?.icon
        self.categoryColorHexSnapshot = categoryColorHexSnapshot ?? category?.colorHex
        self.note = note
        self.noteCiphertext = noteCiphertext
        self.noteHash = noteHash
        self.recurrenceFrequencyRaw = recurrenceFrequencyRaw
        self.recurrenceNextDate = recurrenceNextDate
        self.recurrenceSeriesID = recurrenceSeriesID
        self.isRecurringTemplate = isRecurringTemplate
        self.excludedFromBudget = excludedFromBudget
        self.tagsRaw = tagsRaw
        self.splitGroupID = splitGroupID
        self.splitsRaw = splitsRaw
    }

    // MARK: - Recurrence helpers
    var seriesKey: String? { recurrenceSeriesID }
    var isRecurringOccurrence: Bool { (recurrenceSeriesID != nil) && !isRecurringTemplate }

    // MARK: - Multi-category splits
    var hasSplits: Bool { !splits.isEmpty }

    var splits: [CategorySplit] {
        get {
            guard !splitsRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
            guard let data = splitsRaw.data(using: .utf8) else { return [] }
            if let decoded = try? JSONDecoder().decode([CategorySplit].self, from: data) {
                return decoded
            }
            return []
        }
        set {
            if newValue.isEmpty {
                splitsRaw = ""
            } else if let data = try? JSONEncoder().encode(newValue), let json = String(data: data, encoding: .utf8) {
                splitsRaw = json
            }
        }
    }

    /// Apply and normalize splits so that their sum equals the transaction amount.
    func applySplits(_ newSplits: [CategorySplit]) {
        let normalized = SplitAllocator.normalize(splits: newSplits, to: amount)
        self.splits = normalized
    }

    /// Produce a human-readable summary of splits using category names.
    func splitSummary(using categories: [Category]) -> String {
        let names: [String] = splits.compactMap { $0.categoryName }
        if names.isEmpty { return "" }
        if names.count == 1 { return names[0] }
        return names.prefix(2).joined(separator: " + ") + (names.count > 2 ? "…" : "")
    }

    var recurrenceFrequency: RecurrenceFrequency? {
        guard let recurrenceFrequencyRaw else { return nil }
        return RecurrenceFrequency(rawValue: recurrenceFrequencyRaw)
    }

    var resolvedCategoryName: String? {
        if hasSplits { return "Multi-catégories" }
        return categoryNameSnapshot
    }

    var resolvedCategoryIcon: String? {
        if hasSplits { return "📌" }
        return categoryIconSnapshot
    }

    var resolvedCategoryColorHex: String? {
        return categoryColorHexSnapshot
    }

    var tags: [String] {
        get {
            tagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            tagsRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }
}

