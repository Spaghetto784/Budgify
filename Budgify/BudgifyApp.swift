import SwiftUI
import SwiftData

@main
struct BudgifyApp: App {
    @State private var currencyService = CurrencyService()
    @State private var expenseVM = ExpenseViewModel()
    @State private var budgetVM = BudgetViewModel()
    @State private var categoryVM = CategoryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(currencyService)
                .environment(expenseVM)
                .environment(budgetVM)
                .environment(categoryVM)
                .task { await currencyService.fetchRates() }
        }
        .modelContainer(for: [Expense.self, Category.self, Budget.self])
    }
}
