import SwiftUI
import SwiftData

struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(BudgetViewModel.self) private var budgetVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SettingsViewModel.self) private var settingsVM

    @State private var name = ""
    @State private var limit = ""
    @State private var currency = "EUR"
    @State private var month = Date.now
    @State private var isRecurringMonthly = false
    @State private var rolloverUnusedAmount = false

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom (optionnel)", text: $name)
                    DatePicker("Mois", selection: $month, displayedComponents: [.date])
                    TextField("Limite de dépenses", text: $limit)
                        .keyboardType(.decimalPad)
                    Picker("Devise", selection: $currency) {
                        ForEach(displayCurrencies, id: \.self) { c in
                            Text(currencyService.displayLabel(for: c)).tag(c)
                        }
                    }
                }

                Section("Automatisation") {
                    Toggle("Budget récurrent mensuel", isOn: $isRecurringMonthly)
                    if isRecurringMonthly {
                        Toggle("Reporter le restant sur le mois suivant", isOn: $rolloverUnusedAmount)
                    }
                }
            }
            .navigationTitle("Nouveau budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Créer") { save() }
                        .disabled(Double(limit) == nil)
                }
            }
            .onAppear {
                currency = displayCurrencies.first ?? "EUR"
            }
        }
    }

    private func save() {
        guard let lmt = Double(limit) else { return }
        let budget = Budget(
            month: month,
            limit: lmt,
            currency: currency,
            name: name,
            isRecurringMonthly: isRecurringMonthly,
            rolloverUnusedAmount: isRecurringMonthly && rolloverUnusedAmount
        )
        budgetVM.add(budget: budget, context: context)
        dismiss()
    }
}
