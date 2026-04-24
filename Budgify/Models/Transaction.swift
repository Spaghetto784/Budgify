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
        isRecurringTemplate: Bool = false
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
    }

    var recurrenceFrequency: RecurrenceFrequency? {
        guard let recurrenceFrequencyRaw else { return nil }
        return RecurrenceFrequency(rawValue: recurrenceFrequencyRaw)
    }

    var resolvedCategoryName: String? {
        categoryNameSnapshot
    }

    var resolvedCategoryIcon: String? {
        categoryIconSnapshot
    }

    var resolvedCategoryColorHex: String? {
        categoryColorHexSnapshot
    }
}
