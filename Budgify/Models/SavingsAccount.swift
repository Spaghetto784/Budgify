import SwiftData
import Foundation

@Model
final class SavingsAccount {
    var name: String
    var balance: Double
    var currency: String
    var icon: String
    var history: [SavingsEntry]

    init(name: String, balance: Double, currency: String = "EUR", icon: String = "🏦") {
        self.name = name
        self.balance = balance
        self.currency = currency
        self.icon = icon
        self.history = []
    }
}

@Model
final class SavingsEntry {
    var date: Date
    var balance: Double
    var note: String

    init(date: Date = .now, balance: Double, note: String = "") {
        self.date = date
        self.balance = balance
        self.note = note
    }
}
