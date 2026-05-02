import SwiftUI
import SwiftData

struct AddSavingsAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SettingsViewModel.self) private var settingsVM

    @State private var name = ""
    @State private var balance = ""
    @State private var currency = "EUR"
    @State private var icon = "🏦"
    @State private var accountType: AccountType = .bank

    private let icons = ["🏦", "💰", "🐖", "📈", "🏠", "✈️", "🎓", "💎"]

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du compte", text: $name)
                    TextField("Solde initial", text: $balance)
                        .keyboardType(.decimalPad)
                    Picker("Type de compte", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    Picker("Devise", selection: $currency) {
                        ForEach(displayCurrencies, id: \.self) { code in
                            Text(currencyService.displayLabel(for: code)).tag(code)
                        }
                    }
                }

                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(icons, id: \.self) { i in
                            Text(i)
                                .font(.title2)
                                .padding(6)
                                .background(icon == i ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { icon = i }
                        }
                    }
                }
            }
            .navigationTitle("Nouveau compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Créer") { save() }
                        .disabled(name.isEmpty || NumberParsing.parseDouble(balance) == nil)
                }
            }
            .onAppear {
                currency = displayCurrencies.first ?? "EUR"
            }
        }
    }

    private func save() {
        guard let bal = NumberParsing.parseDouble(balance) else { return }
        savingsVM.addAccount(account: SavingsAccount(name: name, balance: bal, currency: currency, icon: icon, accountType: accountType), context: context)
        dismiss()
    }
}
