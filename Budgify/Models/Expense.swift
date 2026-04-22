import SwiftData
import Foundation

@Model
final class Expense {
    var title: String
    var amount: Double
    var date: Date
    var currency: String
    var category: Category

    init(title: String, amount: Double, date: Date = .now, currency: String = "EUR", category: Category) {
        self.title = title
        self.amount = amount
        self.date = date
        self.currency = currency
        self.category = category
    }
}
