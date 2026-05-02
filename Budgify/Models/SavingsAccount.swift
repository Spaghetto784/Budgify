import SwiftData
import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case bank
    case cash
    case card

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bank: return "Banque"
        case .cash: return "Cash"
        case .card: return "Carte"
        }
    }
}

@Model
final class SavingsAccount {
    var name: String
    var balance: Double
    var currency: String
    var icon: String
    var accountTypeRaw: String
    var history: [SavingsEntry]

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .bank }
        set { accountTypeRaw = newValue.rawValue }
    }

    init(name: String, balance: Double, currency: String = "EUR", icon: String = "🏦", accountType: AccountType = .bank) {
        self.name = name
        self.balance = balance
        self.currency = currency
        self.icon = icon
        self.accountTypeRaw = accountType.rawValue
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
