import SwiftData
import Foundation

@Model
final class Budget {
    var month: Date
    var limit: Double
    var currency: String

    init(month: Date, limit: Double, currency: String = "EUR") {
        self.month = month
        self.limit = limit
        self.currency = currency
    }
}
