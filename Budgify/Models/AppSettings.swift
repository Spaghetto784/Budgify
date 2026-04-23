import SwiftData
import Foundation

@Model
final class AppSettings {
    var accentColorHex: String
    var backgroundStyle: String
    var faceIDEnabled: Bool
    var primaryCurrency: String
    var secondaryCurrency: String
    var preferredCurrencies: [String]
    var protectedTabs: [String]
    var budgetAlertsEnabled: Bool
    var dataEncryptionEnabled: Bool

    init() {
        self.accentColorHex = "27AE60"
        self.backgroundStyle = "system"
        self.faceIDEnabled = false
        self.primaryCurrency = "EUR"
        self.secondaryCurrency = "USD"
        self.preferredCurrencies = ["EUR", "USD"]
        self.protectedTabs = []
        self.budgetAlertsEnabled = false
        self.dataEncryptionEnabled = false
    }
}
