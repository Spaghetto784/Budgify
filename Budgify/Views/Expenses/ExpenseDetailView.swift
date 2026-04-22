import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    @Environment(ExpenseViewModel.self) private var expenseVM
    let expense: Expense
    @State private var selectedCurrency: String

    init(expense: Expense) {
        self.expense = expense
        _selectedCurrency = State(initialValue: expense.currency)
    }

    private var convertedAmount: Double {
        if expense.currency == selectedCurrency { return expense.amount }
        if selectedCurrency == "THB", let rate = currencyService.rates["THB"] { return expense.amount * rate }
        if selectedCurrency == "EUR", let rate = currencyService.rates["THB"] { return expense.amount / rate }
        return expense.amount
    }

    private var symbol: String { selectedCurrency == "EUR" ? "€" : "฿" }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(expense.category.icon)
                        .font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text(expense.title)
                            .font(.title3.bold())
                        Text(expense.category.name)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Montant") {
                Picker("", selection: $selectedCurrency) {
                    Text("EUR €").tag("EUR")
                    Text("THB ฿").tag("THB")
                }
                .pickerStyle(.segmented)
                Text("\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.title.bold())
            }
            Section("Date") {
                Text(expense.date.formatted(date: .long, time: .omitted))
            }
            Section {
                Button(role: .destructive) {
                    expenseVM.delete(expense: expense, context: context)
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
