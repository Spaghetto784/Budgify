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
    @State private var startDate = Date.now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
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
                    DatePicker("Date de début", selection: $startDate, displayedComponents: [.date])
                    DatePicker("Date de fin", selection: $endDate, in: startDate..., displayedComponents: [.date])
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
                        Toggle("Reporter le restant sur la période suivante", isOn: $rolloverUnusedAmount)
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
                        .disabled(NumberParsing.parseDouble(limit) == nil || endDate < startDate)
                }
            }
            .onAppear {
                currency = displayCurrencies.first ?? "EUR"
            }
        }
    }

    private func save() {
        guard let lmt = NumberParsing.parseDouble(limit) else { return }
        let budget = Budget(
            month: startDate,
            startDate: startDate,
            endDate: endDate,
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
