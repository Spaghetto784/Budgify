import SwiftUI
import SwiftData

@main
struct BudgifyApp: App {
    @State private var currencyService = CurrencyService()
    @State private var transactionVM = TransactionViewModel()
    @State private var budgetVM = BudgetViewModel()
    @State private var categoryVM = CategoryViewModel()
    @State private var savingsVM = SavingsViewModel()
    @State private var classifier = CategoryClassifier()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(currencyService)
                .environment(transactionVM)
                .environment(budgetVM)
                .environment(categoryVM)
                .environment(savingsVM)
                .environment(classifier)
                .task { await currencyService.fetchRates() }
        }
        .modelContainer(for: [Transaction.self, Category.self, Budget.self, SavingsAccount.self, SavingsEntry.self, SavingsGoal.self])
    }
}
