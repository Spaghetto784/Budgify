import SwiftUI
import SwiftData

struct TransferFundsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM
    @Environment(CurrencyService.self) private var currencyService
    @Query private var accounts: [SavingsAccount]

    @State private var sourceAccount: SavingsAccount?
    @State private var destinationAccount: SavingsAccount?
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    Picker("Compte source", selection: $sourceAccount) {
                        Text("Sélectionner").tag(Optional<SavingsAccount>.none)
                        ForEach(accounts) { account in
                            Text("\(account.icon) \(account.name) (\(account.currency))")
                                .tag(Optional(account))
                        }
                    }
                }

                Section("Destination") {
                    Picker("Compte destination", selection: $destinationAccount) {
                        Text("Sélectionner").tag(Optional<SavingsAccount>.none)
                        ForEach(destinationCandidates) { account in
                            Text("\(account.icon) \(account.name) (\(account.currency))")
                                .tag(Optional(account))
                        }
                    }
                }

                Section("Montant") {
                    TextField("Montant", text: $amount)
                        .keyboardType(.decimalPad)
                    if let sourceAccount {
                        Text("Devise du débit: \(sourceAccount.currency)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Virement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Valider") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                sourceAccount = accounts.first
                destinationAccount = accounts.dropFirst().first
            }
        }
    }

    private var destinationCandidates: [SavingsAccount] {
        guard let sourceAccount else { return accounts }
        return accounts.filter { $0.id != sourceAccount.id }
    }

    private var isValid: Bool {
        guard
            let sourceAccount,
            let destinationAccount,
            sourceAccount.id != destinationAccount.id
        else { return false }
        guard let parsed = NumberParsing.parseDouble(amount) else { return false }
        return parsed > 0
    }

    private func save() {
        guard
            let sourceAccount,
            let destinationAccount,
            let parsedAmount = NumberParsing.parseDouble(amount)
        else { return }

        savingsVM.transfer(
            from: sourceAccount,
            to: destinationAccount,
            amount: parsedAmount,
            currencyService: currencyService,
            context: context
        )
        dismiss()
    }
}

