import Foundation
import SwiftData

@Observable
final class DataBackupService {
    private struct SnapshotEnvelope: Codable {
        var payloadBase64: String
        var payloadHash: String
        var createdAt: Date
    }

    private struct Snapshot: Codable {
        var categories: [CategorySnapshot]
        var transactions: [TransactionSnapshot]
        var budgets: [BudgetSnapshot]
        var savingsAccounts: [SavingsAccountSnapshot]
        var savingsGoals: [SavingsGoalSnapshot]
        var settings: [SettingsSnapshot]
    }

    private struct CategorySnapshot: Codable {
        var name: String
        var colorHex: String
        var icon: String
    }

    private struct TransactionSnapshot: Codable {
        var title: String
        var amount: Double
        var date: Date
        var currency: String
        var typeRaw: String
        var categoryName: String?
        var categoryIcon: String?
        var categoryColorHex: String?
        var note: String
        var noteCiphertext: String?
        var noteHash: String?
        var recurrenceFrequencyRaw: String?
        var recurrenceNextDate: Date?
        var recurrenceSeriesID: String?
        var isRecurringTemplate: Bool
    }

    private struct BudgetSnapshot: Codable {
        var month: Date
        var limit: Double
        var currency: String
        var name: String
        var isRecurringMonthly: Bool
        var rolloverUnusedAmount: Bool
        var rolloverFromPreviousMonth: Double
    }

    private struct SavingsEntrySnapshot: Codable {
        var date: Date
        var balance: Double
        var note: String
    }

    private struct SavingsAccountSnapshot: Codable {
        var name: String
        var balance: Double
        var currency: String
        var icon: String
        var history: [SavingsEntrySnapshot]
    }

    private struct SavingsGoalSnapshot: Codable {
        var name: String
        var target: Double
        var current: Double
        var currency: String
        var deadline: Date?
        var icon: String
    }

    private struct SettingsSnapshot: Codable {
        var accentColorHex: String
        var backgroundStyle: String
        var faceIDEnabled: Bool
        var primaryCurrency: String
        var secondaryCurrency: String
        var preferredCurrencies: [String]
        var protectedTabs: [String]
        var budgetAlertsEnabled: Bool
        var dataEncryptionEnabled: Bool
    }

    private let securityService = SecurityService()

    private var backupURL: URL? {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupport.appendingPathComponent("BudgifyBackup.enc")
        } catch {
            return nil
        }
    }

    func saveSnapshot(
        transactions: [Transaction],
        budgets: [Budget],
        accounts: [SavingsAccount],
        goals: [SavingsGoal],
        categories: [Category],
        settings: [AppSettings]
    ) {
        guard let backupURL else { return }

        let snapshot = Snapshot(
            categories: categories.map { .init(name: $0.name, colorHex: $0.colorHex, icon: $0.icon) },
            transactions: transactions.map {
                .init(
                    title: $0.title,
                    amount: $0.amount,
                    date: $0.date,
                    currency: $0.currency,
                    typeRaw: $0.type.rawValue,
                    categoryName: $0.resolvedCategoryName,
                    categoryIcon: $0.resolvedCategoryIcon,
                    categoryColorHex: $0.resolvedCategoryColorHex,
                    note: $0.note,
                    noteCiphertext: $0.noteCiphertext,
                    noteHash: $0.noteHash,
                    recurrenceFrequencyRaw: $0.recurrenceFrequencyRaw,
                    recurrenceNextDate: $0.recurrenceNextDate,
                    recurrenceSeriesID: $0.recurrenceSeriesID,
                    isRecurringTemplate: $0.isRecurringTemplate
                )
            },
            budgets: budgets.map {
                .init(
                    month: $0.month,
                    limit: $0.limit,
                    currency: $0.currency,
                    name: $0.name,
                    isRecurringMonthly: $0.isRecurringMonthly,
                    rolloverUnusedAmount: $0.rolloverUnusedAmount,
                    rolloverFromPreviousMonth: $0.rolloverFromPreviousMonth
                )
            },
            savingsAccounts: accounts.map {
                .init(
                    name: $0.name,
                    balance: $0.balance,
                    currency: $0.currency,
                    icon: $0.icon,
                    history: $0.history.map { .init(date: $0.date, balance: $0.balance, note: $0.note) }
                )
            },
            savingsGoals: goals.map {
                .init(
                    name: $0.name,
                    target: $0.target,
                    current: $0.current,
                    currency: $0.currency,
                    deadline: $0.deadline,
                    icon: $0.icon
                )
            },
            settings: settings.map {
                .init(
                    accentColorHex: $0.accentColorHex,
                    backgroundStyle: $0.backgroundStyle,
                    faceIDEnabled: $0.faceIDEnabled,
                    primaryCurrency: $0.primaryCurrency,
                    secondaryCurrency: $0.secondaryCurrency,
                    preferredCurrencies: $0.preferredCurrencies,
                    protectedTabs: $0.protectedTabs,
                    budgetAlertsEnabled: $0.budgetAlertsEnabled,
                    dataEncryptionEnabled: $0.dataEncryptionEnabled
                )
            }
        )

        do {
            let plaintext = try JSONEncoder().encode(snapshot)
            guard let encrypted = securityService.encrypt(data: plaintext) else { return }

            let envelope = SnapshotEnvelope(
                payloadBase64: encrypted.base64EncodedString(),
                payloadHash: securityService.hash(data: plaintext),
                createdAt: .now
            )

            let envelopeData = try JSONEncoder().encode(envelope)
            try envelopeData.write(to: backupURL, options: .atomic)
        } catch {
            return
        }
    }

    @discardableResult
    func restoreIfNeeded(
        context: ModelContext,
        transactions: [Transaction],
        budgets: [Budget],
        accounts: [SavingsAccount],
        goals: [SavingsGoal],
        categories: [Category],
        settings: [AppSettings]
    ) -> Bool {
        guard transactions.isEmpty,
              budgets.isEmpty,
              accounts.isEmpty,
              goals.isEmpty,
              categories.isEmpty,
              settings.isEmpty,
              let backupURL
        else {
            return false
        }

        do {
            let data = try Data(contentsOf: backupURL)
            let envelope = try JSONDecoder().decode(SnapshotEnvelope.self, from: data)
            guard let payloadData = Data(base64Encoded: envelope.payloadBase64),
                  let decrypted = securityService.decrypt(data: payloadData),
                  securityService.hash(data: decrypted) == envelope.payloadHash
            else {
                return false
            }

            let snapshot = try JSONDecoder().decode(Snapshot.self, from: decrypted)

            for category in snapshot.categories {
                let model = Category(name: category.name, colorHex: category.colorHex, icon: category.icon)
                context.insert(model)
            }

            for transaction in snapshot.transactions {
                let model = Transaction(
                    title: transaction.title,
                    amount: transaction.amount,
                    date: transaction.date,
                    currency: transaction.currency,
                    type: TransactionType(rawValue: transaction.typeRaw) ?? .expense,
                    category: nil,
                    categoryNameSnapshot: transaction.categoryName,
                    categoryIconSnapshot: transaction.categoryIcon,
                    categoryColorHexSnapshot: transaction.categoryColorHex,
                    note: transaction.note,
                    noteCiphertext: transaction.noteCiphertext,
                    noteHash: transaction.noteHash,
                    recurrenceFrequencyRaw: transaction.recurrenceFrequencyRaw,
                    recurrenceNextDate: transaction.recurrenceNextDate,
                    recurrenceSeriesID: transaction.recurrenceSeriesID,
                    isRecurringTemplate: transaction.isRecurringTemplate
                )
                context.insert(model)
            }

            for budget in snapshot.budgets {
                let model = Budget(
                    month: budget.month,
                    limit: budget.limit,
                    currency: budget.currency,
                    name: budget.name,
                    isRecurringMonthly: budget.isRecurringMonthly,
                    rolloverUnusedAmount: budget.rolloverUnusedAmount,
                    rolloverFromPreviousMonth: budget.rolloverFromPreviousMonth
                )
                context.insert(model)
            }

            for account in snapshot.savingsAccounts {
                let model = SavingsAccount(
                    name: account.name,
                    balance: account.balance,
                    currency: account.currency,
                    icon: account.icon
                )

                for entry in account.history {
                    let historyEntry = SavingsEntry(date: entry.date, balance: entry.balance, note: entry.note)
                    context.insert(historyEntry)
                    model.history.append(historyEntry)
                }

                context.insert(model)
            }

            for goal in snapshot.savingsGoals {
                let model = SavingsGoal(
                    name: goal.name,
                    target: goal.target,
                    current: goal.current,
                    currency: goal.currency,
                    deadline: goal.deadline,
                    icon: goal.icon
                )
                context.insert(model)
            }

            for settingsItem in snapshot.settings {
                let model = AppSettings()
                model.accentColorHex = settingsItem.accentColorHex
                model.backgroundStyle = settingsItem.backgroundStyle
                model.faceIDEnabled = settingsItem.faceIDEnabled
                model.primaryCurrency = settingsItem.primaryCurrency
                model.secondaryCurrency = settingsItem.secondaryCurrency
                model.preferredCurrencies = settingsItem.preferredCurrencies
                model.protectedTabs = settingsItem.protectedTabs
                model.budgetAlertsEnabled = settingsItem.budgetAlertsEnabled
                model.dataEncryptionEnabled = settingsItem.dataEncryptionEnabled
                context.insert(model)
            }

            try context.save()
            return true
        } catch {
            return false
        }
    }
}
