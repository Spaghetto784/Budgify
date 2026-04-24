import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(SecurityService.self) private var securityService

    let transaction: Transaction
    @State private var selectedCurrency: String

    init(transaction: Transaction) {
        self.transaction = transaction
        _selectedCurrency = State(initialValue: transaction.currency)
    }

    private var convertedAmount: Double {
        currencyService.convert(amount: transaction.amount, from: transaction.currency, to: selectedCurrency)
    }

    private var symbol: String { currencyService.symbol(for: selectedCurrency) }

    private var displayCurrencies: [String] {
        let selected = settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
        if selected.contains(transaction.currency) {
            return selected
        }
        return selected + [transaction.currency]
    }

    private var displayNote: String {
        if let ciphertext = transaction.noteCiphertext,
           let decrypted = securityService.decrypt(ciphertext) {
            return decrypted
        }
        return transaction.note
    }

    private var noteIntegrityValid: Bool? {
        guard let expectedHash = transaction.noteHash, !displayNote.isEmpty else { return nil }
        return securityService.hash(displayNote) == expectedHash
    }

    private var typeLabel: String {
        switch transaction.type {
        case .expense: return "Dépense"
        case .income: return "Revenu"
        case .loan: return "Prêt"
        }
    }

    private var typeColor: Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .loan: return .orange
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    if let icon = transaction.resolvedCategoryIcon {
                        Text(icon).font(.largeTitle)
                    }
                    VStack(alignment: .leading) {
                        Text(transaction.title).font(.title3.bold())
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundStyle(typeColor)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Montant") {
                Picker("Devise", selection: $selectedCurrency) {
                    ForEach(displayCurrencies, id: \.self) { code in
                        Text(currencyService.displayLabel(for: code)).tag(code)
                    }
                }
                .pickerStyle(.menu)

                Text("\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.title.bold())
                    .foregroundStyle(typeColor)
            }

            Section("Date") {
                Text(transaction.date.formatted(date: .long, time: .omitted))
            }

            if !displayNote.isEmpty {
                Section("Note") {
                    Text(displayNote)
                    if transaction.noteCiphertext != nil {
                        Label("Note chiffrée (AES-256)", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let integrity = noteIntegrityValid {
                        Label(integrity ? "Intégrité hash validée" : "Alerte: hash invalide", systemImage: integrity ? "checkmark.seal" : "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(integrity ? .green : .red)
                    }
                }
            }

            if let name = transaction.resolvedCategoryName {
                Section("Catégorie") {
                    HStack {
                        Text(transaction.resolvedCategoryIcon ?? "📌")
                        Text(name)
                        Spacer()
                        if let colorHex = transaction.resolvedCategoryColorHex {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    transactionVM.delete(transaction: transaction, context: context)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Supprimer")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
