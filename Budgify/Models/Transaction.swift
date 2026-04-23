import SwiftData
import Foundation

enum TransactionType: String, Codable {
    case expense
    case income
    case loan
}

@Model
final class Transaction {
    var title: String
    var amount: Double
    var date: Date
    var currency: String
    var type: TransactionType
    var category: Category?
    var note: String

    init(title: String, amount: Double, date: Date = .now, currency: String = "EUR", type: TransactionType, category: Category? = nil, note: String = "") {
        self.title = title
        self.amount = amount
        self.date = date
        self.currency = currency
        self.type = type
        self.category = category
        self.note = note
    }
}
