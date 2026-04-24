import SwiftData
import Foundation
import LocalAuthentication
import UserNotifications

struct EncryptionRotationResult {
    var rotated: Bool
    var reencryptedCount: Int
}

@Observable
final class SettingsViewModel {
    var settings: AppSettings?
    var isUnlocked = false
    var unlockedTabs: Set<String> = []

    func load(from settings: [AppSettings], context: ModelContext) {
        if let existing = settings.first {
            normalizeCurrencies(existing, context: context)
            self.settings = existing
        } else {
            let newSettings = AppSettings()
            context.insert(newSettings)
            try? context.save()
            self.settings = newSettings
        }
    }

    func save(context: ModelContext) {
        try? context.save()
    }

    func selectedCurrencies(available: [String]) -> [String] {
        guard let settings else { return ["EUR"] }
        let source = settings.preferredCurrencies.isEmpty
            ? [settings.primaryCurrency, settings.secondaryCurrency]
            : settings.preferredCurrencies

        var seen = Set<String>()
        let filtered = source.filter { code in
            guard available.contains(code) else { return false }
            if seen.contains(code) { return false }
            seen.insert(code)
            return true
        }

        return filtered.isEmpty ? ["EUR"] : filtered
    }

    func toggleCurrency(_ code: String, available: [String], context: ModelContext) {
        guard let settings else { return }
        var selected = selectedCurrencies(available: available)

        if selected.contains(code) {
            guard selected.count > 1 else { return }
            selected.removeAll { $0 == code }
        } else {
            selected.append(code)
        }

        settings.preferredCurrencies = selected
        settings.primaryCurrency = selected.first ?? "EUR"
        settings.secondaryCurrency = selected.dropFirst().first ?? settings.primaryCurrency
        save(context: context)
    }

    func isTabProtected(_ tab: String) -> Bool {
        guard settings?.faceIDEnabled == true else { return false }
        return settings?.protectedTabs.contains(tab) == true
    }

    func isTabUnlocked(_ tab: String) -> Bool {
        unlockedTabs.contains(tab)
    }

    func authenticate(for tab: String) async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard await MainActor.run(body: { context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) }) else {
            await MainActor.run { _ = unlockedTabs.insert(tab) }
            return true
        }
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Accéder à \(tab)"
            )
            if result {
                await MainActor.run { _ = unlockedTabs.insert(tab) }
            }
            return result
        } catch {
            return false
        }
    }

    func setBudgetAlertsEnabled(_ enabled: Bool, context: ModelContext) {
        if enabled {
            Task {
                let granted = await requestNotificationPermission()
                await MainActor.run {
                    settings?.budgetAlertsEnabled = granted
                    save(context: context)
                }
            }
        } else {
            settings?.budgetAlertsEnabled = false
            save(context: context)
        }
    }

    func rotateEncryptionKey(context: ModelContext, securityService: SecurityService) -> EncryptionRotationResult {
        guard let transactions = try? context.fetch(FetchDescriptor<Transaction>()) else {
            return .init(rotated: false, reencryptedCount: 0)
        }

        var plaintextByID: [PersistentIdentifier: String] = [:]

        for transaction in transactions {
            guard let cipher = transaction.noteCiphertext,
                  let plaintext = securityService.decrypt(cipher)
            else {
                continue
            }
            plaintextByID[transaction.persistentModelID] = plaintext
        }

        securityService.rotateKey()

        var count = 0
        for transaction in transactions {
            if let plaintext = plaintextByID[transaction.persistentModelID],
               let newCipher = securityService.encrypt(plaintext) {
                transaction.noteCiphertext = newCipher
                transaction.noteHash = securityService.hash(plaintext)
                count += 1
            }
        }

        try? context.save()
        return .init(rotated: true, reencryptedCount: count)
    }

    func lockAllTabs() {
        unlockedTabs.removeAll()
    }

    private func normalizeCurrencies(_ settings: AppSettings, context: ModelContext) {
        var selected = settings.preferredCurrencies

        if selected.isEmpty {
            selected = [settings.primaryCurrency, settings.secondaryCurrency]
        }

        var seen = Set<String>()
        selected = selected.filter { code in
            if code.isEmpty || seen.contains(code) { return false }
            seen.insert(code)
            return true
        }

        if selected.isEmpty {
            selected = ["EUR", "USD"]
        }

        settings.preferredCurrencies = selected
        settings.primaryCurrency = selected.first ?? "EUR"
        settings.secondaryCurrency = selected.dropFirst().first ?? settings.primaryCurrency
        try? context.save()
    }

    private func requestNotificationPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
