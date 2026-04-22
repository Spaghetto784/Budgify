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
        NavigationStack {
            List {
                ForEach(expenses) { expense in
                    ExpenseRowView(expense: expense, displayCurrency: selectedCurrency, rates: currencyService.rates)
                }
                .onDelete { indexSet in
                    indexSet.forEach { expenseVM.delete(expense: expenses[$0], context: context) }
                }
            }
            .navigationTitle("Budgify")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("", selection: $selectedCurrency) {
                        Text("EUR").tag("EUR")
                        Text("THB").tag("THB")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
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
}
