import SwiftData
import Foundation

@Model
final class Budget {
    var month: Date
    var limit: Double
    var currency: String
    var name: String
    var isRecurringMonthly: Bool
    var rolloverUnusedAmount: Bool
    var rolloverFromPreviousMonth: Double

    init(
        month: Date,
        limit: Double,
        currency: String = "EUR",
        name: String = "",
        isRecurringMonthly: Bool = false,
        rolloverUnusedAmount: Bool = false,
        rolloverFromPreviousMonth: Double = 0
    ) {
        self.month = month
        self.limit = limit
        self.currency = currency
        self.name = name
        self.isRecurringMonthly = isRecurringMonthly
        self.rolloverUnusedAmount = rolloverUnusedAmount
        self.rolloverFromPreviousMonth = rolloverFromPreviousMonth
    }
}
