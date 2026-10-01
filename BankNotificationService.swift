import Foundation
import UserNotifications
import SwiftUI
import SwiftData

/// Service to handle bank notifications and extract transaction data
/// This is a foundation for Revolut integration - requires notification permission
@Observable
class BankNotificationService {
    
    var lastDetectedTransaction: DetectedTransaction?
    var isMonitoring: Bool = false
    
    // MARK: - Setup
    
    /// Request notification permission and register for monitoring
    func requestPermissionAndSetup() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                isMonitoring = true
            }
            return granted
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }
    
    // MARK: - Transaction Detection
    
    /// Parses a notification to detect bank transaction
    /// Note: iOS doesn't provide direct access to other apps' notifications
    /// This is a conceptual implementation showing what patterns to detect
    func parseNotificationContent(_ content: String) -> DetectedTransaction? {
        // Common patterns for Revolut notifications
        let patterns = [
            // "You spent €45.50 at Starbucks"
            #"(?:spent|payé|dépensé)\s+([€$£]?\s*[\d,\.]+)\s+(?:at|chez|à)\s+(.+)"#,
            
            // "Card payment -€23.45 SuperMarket"
            #"(?:payment|paiement)[\s\-]+([€$£]?\s*[\d,\.]+)\s+(.+)"#,
            
            // "Received €100.00 from John"
            #"(?:received|reçu)\s+([€$£]?\s*[\d,\.]+)\s+(?:from|de)\s+(.+)"#,
            
            // "-€15.99 • Amazon"
            #"[\-]?([€$£]?\s*[\d,\.]+)\s*[•·]\s*(.+)"#
        ]
        
        for pattern in patterns {
            if let detected = detectTransaction(in: content, pattern: pattern) {
                return detected
            }
        }
        
        return nil
    }
    
    private func detectTransaction(in text: String, pattern: String) -> DetectedTransaction? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }
        
        // Extract amount
        guard match.numberOfRanges >= 2,
              let amountRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        let amountString = String(text[amountRange])
        guard let amount = parseAmount(amountString) else {
            return nil
        }
        
        // Extract merchant/title
        var title = "Transaction"
        if match.numberOfRanges >= 3,
           let titleRange = Range(match.range(at: 2), in: text) {
            title = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Detect transaction type
        let type: TransactionType = amount < 0 ? .expense : .income
        
        // Detect currency
        let currency = detectCurrency(in: amountString)
        
        return DetectedTransaction(
            title: title,
            amount: abs(amount),
            currency: currency,
            type: type,
            rawNotification: text,
            detectedAt: Date()
        )
    }
    
    private func parseAmount(_ string: String) -> Double? {
        // Remove currency symbols
        var cleaned = string
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        // Handle negative sign
        let isNegative = cleaned.hasPrefix("-")
        if isNegative {
            cleaned.removeFirst()
        }
        
        guard let value = Double(cleaned) else {
            return nil
        }
        
        return isNegative ? -value : value
    }
    
    private func detectCurrency(in string: String) -> String {
        if string.contains("€") { return "EUR" }
        if string.contains("$") { return "USD" }
        if string.contains("£") { return "GBP" }
        if string.contains("¥") { return "JPY" }
        return "EUR" // Default
    }
    
    // MARK: - Smart Categorization
    
    /// Suggests a category based on merchant name
    func suggestCategory(for merchant: String, categories: [Category]) -> Category? {
        let merchantLower = merchant.lowercased()
        
        // Common merchant patterns
        let categoryKeywords: [String: [String]] = [
            "Nourriture": ["restaurant", "cafe", "coffee", "pizza", "burger", "food", "mcdo", "kfc", "starbucks", "subway"],
            "Transport": ["uber", "taxi", "train", "metro", "bus", "parking", "fuel", "essence", "gas", "station"],
            "Shopping": ["amazon", "ebay", "shop", "store", "mall", "boutique", "zara", "h&m", "nike", "adidas"],
            "Loisirs": ["cinema", "netflix", "spotify", "game", "xbox", "playstation", "steam", "movie", "theatre"],
            "Santé": ["pharmacy", "doctor", "hospital", "clinic", "pharmacie", "medic", "health"],
            "Logement": ["rent", "loyer", "electricity", "water", "internet", "edf", "orange", "sfr", "free"]
        ]
        
        for (categoryName, keywords) in categoryKeywords {
            if keywords.contains(where: { merchantLower.contains($0) }) {
                return categories.first { $0.name == categoryName }
            }
        }
        
        return nil
    }
}

// MARK: - Models

struct DetectedTransaction: Identifiable, Codable {
    let id = UUID()
    let title: String
    let amount: Double
    let currency: String
    let type: TransactionType
    let rawNotification: String
    let detectedAt: Date
    var isConfirmed: Bool = false
    var suggestedCategory: String?
    
    var displayAmount: String {
        let symbol = currencySymbol(for: currency)
        return "\(symbol)\(String(format: "%.2f", amount))"
    }
    
    private func currencySymbol(for code: String) -> String {
        switch code {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return code
        }
    }
}

// MARK: - SwiftUI Integration View

struct BankNotificationSetupView: View {
    @State private var notificationService = BankNotificationService()
    @State private var showPermissionAlert = false
    @State private var permissionGranted = false
    @State private var testNotificationText = ""
    @State private var detectedTransaction: DetectedTransaction?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.blue)
                                .font(.title)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Détection automatique")
                                    .font(.headline)
                                Text("Capturez les transactions bancaires automatiquement")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if notificationService.isMonitoring {
                            Label("Surveillance active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Intégration bancaire")
                }
                
                Section {
                    Text("Cette fonctionnalité nécessite l'autorisation des notifications et fonctionne en détectant les patterns dans les notifications de votre application bancaire.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !notificationService.isMonitoring {
                        Button {
                            Task {
                                permissionGranted = await notificationService.requestPermissionAndSetup()
                                showPermissionAlert = true
                            }
                        } label: {
                            Label("Activer la détection", systemImage: "bell.and.waveform.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Text("Configuration")
                }
                
                Section {
                    TextField("Ex: You spent €45.50 at Starbucks", text: $testNotificationText, axis: .vertical)
                        .lineLimit(2...5)
                    
                    Button("Tester la détection") {
                        detectedTransaction = notificationService.parseNotificationContent(testNotificationText)
                    }
                    .disabled(testNotificationText.isEmpty)
                    
                    if let detected = detectedTransaction {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Transaction détectée")
                                    .font(.headline)
                            }
                            
                            LabeledContent("Titre", value: detected.title)
                            LabeledContent("Montant", value: detected.displayAmount)
                            LabeledContent("Type", value: detected.type == .expense ? "Dépense" : "Revenu")
                            LabeledContent("Devise", value: detected.currency)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Test")
                } footer: {
                    Text("Formats supportés : 'spent €X at Y', 'Card payment -€X Y', 'Received €X from Y', '-€X • Y'")
                        .font(.caption2)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Revolut", systemImage: "creditcard.fill")
                            .foregroundStyle(.blue)
                        Label("N26", systemImage: "creditcard.fill")
                            .foregroundStyle(.orange)
                        Label("Wise", systemImage: "creditcard.fill")
                            .foregroundStyle(.green)
                        Label("La plupart des banques", systemImage: "building.columns.fill")
                            .foregroundStyle(.gray)
                    }
                    .font(.caption)
                } header: {
                    Text("Applications supportées")
                } footer: {
                    Text("⚠️ Note : iOS ne permet pas l'accès direct aux notifications d'autres apps. Cette fonctionnalité est conceptuelle et nécessiterait une intégration API directe avec votre banque.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .navigationTitle("Intégration bancaire")
            .alert("Notifications", isPresented: $showPermissionAlert) {
                Button("OK") {}
            } message: {
                Text(permissionGranted ? 
                     "Détection activée ! Les transactions seront reconnues automatiquement." : 
                     "Permission refusée. Activez les notifications dans les réglages.")
            }
        }
    }
}

// MARK: - Quick Add Transaction from Detected

struct QuickAddFromDetectedView: View {
    let detected: DetectedTransaction
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TransactionViewModel.self) private var transactionVM
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Titre", value: detected.title)
                    LabeledContent("Montant", value: detected.displayAmount)
                    LabeledContent("Type", value: detected.type == .expense ? "Dépense" : "Revenu")
                }
                
                Section {
                    Text("Cette transaction a été détectée automatiquement. Vérifiez les informations avant de l'ajouter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Confirmer transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        addTransaction()
                    }
                }
            }
        }
    }
    
    private func addTransaction() {
        let transaction = Transaction(
            title: detected.title,
            amount: detected.amount,
            date: detected.detectedAt,
            currency: detected.currency,
            type: detected.type,
            category: nil,
            categoryNameSnapshot: detected.suggestedCategory,
            categoryIconSnapshot: nil,
            categoryColorHexSnapshot: nil,
            note: "Détectée automatiquement",
            noteCiphertext: nil,
            noteHash: nil,
            excludedFromBudget: false,
            tagsRaw: "auto"
        )
        
        transactionVM.add(transaction: transaction, context: context)
        dismiss()
    }
}
