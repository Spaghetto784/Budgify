import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var accounts: [SavingsAccount]
    @Query private var goals: [SavingsGoal]
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(BudgetViewModel.self) private var budgetVM
    @Environment(SavingsViewModel.self) private var savingsVM

    var body: some View {
        TabView {
            NavigationStack {
                TransactionListView()
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet")
            }
            NavigationStack {
                BudgetView()
            }
            .tabItem {
                Label("Budget", systemImage: "chart.bar")
            }
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.pie")
            }
            NavigationStack {
                SavingsView()
            }
            .tabItem {
                Label("Savings", systemImage: "banknote")
            }
            NavigationStack {
                CategoryListView()
            }
            .tabItem {
                Label("Catégories", systemImage: "tag")
            }
        }
        .onAppear {
            transactionVM.transactions = transactions
            budgetVM.budgets = budgets
            savingsVM.accounts = accounts
            savingsVM.goals = goals
        }
    }
}
