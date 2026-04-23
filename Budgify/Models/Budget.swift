import SwiftData
import Foundation

@Model
final class Budget {
    var month: Date
    var limit: Double
    var currency: String
    var name: String

    init(month: Date, limit: Double, currency: String = "EUR", name: String = "") {
        self.month = month
        self.limit = limit
        self.currency = currency
        self.name = name
    }
}
