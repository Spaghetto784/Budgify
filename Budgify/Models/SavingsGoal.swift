import SwiftData
import Foundation

@Model
final class SavingsGoal {
    var name: String
    var target: Double
    var current: Double
    var currency: String
    var deadline: Date?
    var icon: String

    init(name: String, target: Double, current: Double = 0, currency: String = "EUR", deadline: Date? = nil, icon: String = "🎯") {
        self.name = name
        self.target = target
        self.current = current
        self.currency = currency
        self.deadline = deadline
        self.icon = icon
    }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
}
