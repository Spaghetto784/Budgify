import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(BudgetViewModel.self) private var budgetVM
    @Environment(ExpenseViewModel.self) private var expenseVM
    @Environment(CurrencyService.self) private var currencyService
    @Query private var budgets: [Budget]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showAdd = false
    @State private var selectedMonth = Date.now
    
    private var currentBudget: Budget? { budgetVM.budget(for: selectedMonth) }
    
    private var spent: Double {
        let currency = currentBudget?.currency ?? "EUR"
        return expenseVM.expenses(for: selectedMonth).reduce(0) { acc, e in
            if e.currency == currency { return acc + e.amount }
            if currency == "THB", let rate = currencyService.rates["THB"] { return acc + e.amount * rate }
            if currency == "EUR", let rate = currencyService.rates["THB"] { return acc + e.amount / rate }
            return acc
        }
    }
    
    private var remaining: Double { (currentBudget?.limit ?? 0) - spent }
    private var progress: Double {
        guard let limit = currentBudget?.limit, limit > 0 else { return 0 }
        return min(spent / limit, 1.0)
    }
    
    var body: some View {
        List {
            Section {
                DatePicker("Mois", selection: $selectedMonth, displayedComponents: [.date])
                    .datePickerStyle(.compact)
            }
            if let budget = currentBudget {
                Section("Progression") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: progress)
                            .tint(progress > 0.8 ? .red : .blue)
                        HStack {
                            Text("Dépensé : \(budget.currency == "EUR" ? "€" : "฿")\(String(format: "%.2f", spent))")
                                .font(.caption)
                            Spacer()
                            Text("Limite : \(budget.currency == "EUR" ? "€" : "฿")\(String(format: "%.2f", budget.limit))")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Restant") {
                    Text("\(budget.currency == "EUR" ? "€" : "฿")\(String(format: "%.2f", remaining))")
                        .font(.title2.bold())
                        .foregroundStyle(remaining < 0 ? .red : .green)
                }
            } else {
                Section {
                    Text("Aucun budget pour ce mois")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBudgetView()
        }
        .onAppear { budgetVM.budgets = budgets; expenseVM.expenses = expenses }
    }
}
