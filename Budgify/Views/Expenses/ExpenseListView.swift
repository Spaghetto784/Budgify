import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService
    @Environment(ExpenseViewModel.self) private var expenseVM
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showAdd = false
    @State private var selectedCurrency = "EUR"

    var body: some View {
        List {
            Section {
                Picker("", selection: $selectedCurrency) {
                    Text("EUR €").tag("EUR")
                    Text("THB ฿").tag("THB")
                }
                .pickerStyle(.segmented)
            }
            Section("Dépenses") {
                ForEach(expenses) { expense in
                    NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                        ExpenseRowView(expense: expense, displayCurrency: selectedCurrency, rates: currencyService.rates)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { expenseVM.delete(expense: expenses[$0], context: context) }
                }
            }
        }
        .navigationTitle("Budgify")
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
            AddExpenseView()
        }
    }
}
