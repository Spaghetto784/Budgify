import SwiftData
import Foundation

@Model
final class Budget {
    var month: Date
    var startDate: Date
    var endDate: Date
    var limit: Double
    var currency: String
    var name: String
    var isRecurringMonthly: Bool
    var rolloverUnusedAmount: Bool
    var rolloverFromPreviousMonth: Double

    init(
        month: Date,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Double,
        currency: String = "EUR",
        name: String = "",
        isRecurringMonthly: Bool = false,
        rolloverUnusedAmount: Bool = false,
        rolloverFromPreviousMonth: Double = 0
    ) {
        let calendar = Calendar.current
        let periodStart = startDate ?? calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let periodEnd = endDate ?? calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart) ?? periodStart

        self.month = periodStart
        self.startDate = periodStart
        self.endDate = max(periodStart, periodEnd)
        self.limit = limit
        self.currency = currency
        self.name = name
        self.isRecurringMonthly = isRecurringMonthly
        self.rolloverUnusedAmount = rolloverUnusedAmount
        self.rolloverFromPreviousMonth = rolloverFromPreviousMonth
    }
}
