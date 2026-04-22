import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var budgets: [Budget]
    @Environment(ExpenseViewModel.self) private var expenseVM
    @Environment(BudgetViewModel.self) private var budgetVM

    var body: some View {
        TabView {
            NavigationStack {
                ExpenseListView()
            }
            .tabItem {
                Label("Dépenses", systemImage: "list.bullet")
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
                CategoryListView()
            }
            .tabItem {
                Label("Catégories", systemImage: "tag")
            }
        }
        .onAppear {
            expenseVM.expenses = expenses
            budgetVM.budgets = budgets
        }
    }
}
