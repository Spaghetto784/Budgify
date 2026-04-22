import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(ExpenseViewModel.self) private var expenseVM
    @Environment(CurrencyService.self) private var currencyService
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var categories: [Category]
    @State private var selectedCurrency = "EUR"
    @State private var selectedMonth = Date.now

    private var symbol: String { selectedCurrency == "EUR" ? "€" : "฿" }

    private var monthlyExpenses: [Expense] {
        expenseVM.expenses(for: selectedMonth)
    }

    private var byCategory: [(name: String, total: Double)] {
        categories.map { cat in
            let total = monthlyExpenses
                .filter { $0.category.id == cat.id }
                .reduce(0.0) { acc, e in
                    if e.currency == selectedCurrency { return acc + e.amount }
                    if selectedCurrency == "THB", let rate = currencyService.rates["THB"] { return acc + e.amount * rate }
                    if selectedCurrency == "EUR", let rate = currencyService.rates["THB"] { return acc + e.amount / rate }
                    return acc
                }
            return (name: cat.name, total: total)
        }
        .filter { $0.total > 0 }
    }

    var body: some View {
            List {
                Section {
                    DatePicker("Mois", selection: $selectedMonth, displayedComponents: [.date])
                    Picker("Devise", selection: $selectedCurrency) {
                        Text("EUR €").tag("EUR")
                        Text("THB ฿").tag("THB")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Dépenses par catégorie") {
                    if byCategory.isEmpty {
                        Text("Aucune dépense ce mois")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(byCategory, id: \.name) { item in
                            SectorMark(
                                angle: .value("Total", item.total),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Catégorie", item.name))
                        }
                        .frame(height: 220)
                        .padding(.vertical)
                    }
                }
                Section("Détail") {
                    ForEach(byCategory, id: \.name) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(symbol)\(String(format: "%.2f", item.total))")
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .onAppear { expenseVM.expenses = expenses }
        }
}
