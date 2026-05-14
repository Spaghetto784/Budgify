import Foundation
import SwiftData

struct RevolutSyncResult {
    let createdTransactions: Int
    let updatedBalance: Double
}

enum RevolutSyncError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "URL backend invalide."
        case .invalidResponse:
            return "Réponse backend invalide."
        case .backendError(let message):
            return message
        }
    }
}

private struct RevolutConnectRequest: Encodable {
    let apiKey: String
}

private struct RevolutConnectResponse: Decodable {
    let connected: Bool
    let message: String?
}

private struct RevolutResetResponse: Decodable {
    let reset: Bool
    let message: String?
}

private struct RevolutSyncBackendResponse: Decodable {
    struct Item: Decodable {
        let id: String
        let title: String
        let amount: Double
        let currency: String
        let bookedAt: Date
    }

    let accountName: String
    let accountCurrency: String
    let accountBalance: Double
    let transactions: [Item]
}

@Observable
final class RevolutSyncService {
    private let connectedStorageKey = "revolut_connected"
    private let backendURLStorageKey = "revolut_backend_url"

    var isConnected: Bool {
        UserDefaults.standard.bool(forKey: connectedStorageKey)
    }

    var backendBaseURL: String {
        UserDefaults.standard.string(forKey: backendURLStorageKey) ?? "http://localhost:8080"
    }

    func setBackendBaseURL(_ url: String) {
        UserDefaults.standard.set(url.trimmingCharacters(in: .whitespacesAndNewlines), forKey: backendURLStorageKey)
    }

    func connect(apiKey: String) async throws -> String {
        let request = RevolutConnectRequest(apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !request.apiKey.isEmpty else { throw RevolutSyncError.backendError("Clé API vide.") }
        let response: RevolutConnectResponse = try await post(path: "/revolut/connect", body: request)
        UserDefaults.standard.set(response.connected, forKey: connectedStorageKey)
        return response.message ?? (response.connected ? "Connexion OK." : "Connexion refusée.")
    }

    func resetConnection() async throws -> String {
        let response: RevolutResetResponse = try await post(path: "/revolut/reset", body: [String: String]())
        UserDefaults.standard.set(false, forKey: connectedStorageKey)
        return response.message ?? (response.reset ? "Connexion réinitialisée." : "Reset refusé.")
    }

    func sync(context: ModelContext) async throws -> RevolutSyncResult {
        let payload: [String: String] = [:]
        let backend: RevolutSyncBackendResponse = try await post(path: "/revolut/sync", body: payload)

        let account = upsertRevolutAccount(
            name: backend.accountName,
            currency: backend.accountCurrency,
            balance: backend.accountBalance,
            context: context
        )

        let existingIDs = existingRevolutTransactionIDs(context: context)
        var createdCount = 0

        for item in backend.transactions where !existingIDs.contains(item.id) {
            let type: TransactionType = item.amount >= 0 ? .income : .expense
            let tx = Transaction(
                title: "Revolut • \(item.title)",
                amount: abs(item.amount),
                date: item.bookedAt,
                currency: item.currency,
                type: type,
                category: nil,
                categoryNameSnapshot: nil,
                categoryIconSnapshot: nil,
                categoryColorHexSnapshot: nil,
                note: "[revolut:id=\(item.id)]"
            )
            context.insert(tx)
            createdCount += 1
        }

        let balanceEntry = SavingsEntry(balance: backend.accountBalance, note: "Sync Revolut")
        context.insert(balanceEntry)
        account.history.append(balanceEntry)
        account.balance = backend.accountBalance
        account.currency = backend.accountCurrency
        account.accountType = .bank

        try? context.save()
        return .init(createdTransactions: createdCount, updatedBalance: backend.accountBalance)
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(path: String, body: RequestBody) async throws -> ResponseBody {
        guard let url = URL(string: backendBaseURL + path) else { throw RevolutSyncError.invalidBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RevolutSyncError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let backendMessage = String(data: data, encoding: .utf8) ?? "Erreur backend"
            throw RevolutSyncError.backendError(backendMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func upsertRevolutAccount(name: String, currency: String, balance: Double, context: ModelContext) -> SavingsAccount {
        let descriptor = FetchDescriptor<SavingsAccount>()
        let accounts = (try? context.fetch(descriptor)) ?? []
        if let existing = accounts.first(where: { $0.name == name }) {
            return existing
        }
        let account = SavingsAccount(
            name: name,
            balance: balance,
            currency: currency,
            icon: "🏦",
            accountType: .bank
        )
        context.insert(account)
        return account
    }

    private func existingRevolutTransactionIDs(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = (try? context.fetch(descriptor)) ?? []
        let prefix = "[revolut:id="
        var ids: Set<String> = []

        for transaction in transactions {
            guard transaction.note.hasPrefix(prefix) else { continue }
            let raw = transaction.note.replacingOccurrences(of: prefix, with: "").replacingOccurrences(of: "]", with: "")
            if !raw.isEmpty {
                ids.insert(raw)
            }
        }
        return ids
    }
}

