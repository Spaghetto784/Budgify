import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var accounts: [SavingsAccount]
    @Query private var goals: [SavingsGoal]
    @Query private var categories: [Category]
    @Query private var settingsList: [AppSettings] = []

    @Environment(\.modelContext) private var context
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(BudgetViewModel.self) private var budgetVM
    @Environment(SavingsViewModel.self) private var savingsVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(DataBackupService.self) private var backupService

    @State private var showSettings = false
    @State private var isLocked = true

    var body: some View {
        rootContent
        .onAppear { handleAppear() }
        .onChange(of: transactions.count) { _, _ in handleTransactionsChanged() }
        .onChange(of: budgets.count) { _, _ in handleBudgetsChanged() }
        .onChange(of: accounts.count) { _, _ in handleAccountsChanged() }
        .onChange(of: goals.count) { _, _ in handleGoalsChanged() }
        .onChange(of: categories.count) { _, _ in persistBackup() }
        .onChange(of: settingsList.count) { _, _ in handleSettingsChanged() }
        .preferredColorScheme(colorScheme)
        .tint(accentColor)
    }

    private var rootContent: AnyView {
        if settingsVM.settings?.faceIDEnabled == true && isLocked {
            return AnyView(lockScreen)
        }
        return AnyView(mainTabView)
    }

    private func handleAppear() {
        let restored = backupService.restoreIfNeeded(
            context: context,
            transactions: transactions,
            budgets: budgets,
            accounts: accounts,
            goals: goals,
            categories: categories,
            settings: settingsList
        )

        if restored {
            syncFromStore()
        } else {
            syncFromQueries()
        }

        transactionVM.generateDueRecurringTransactions(context: context)
        budgetVM.ensureRecurringBudgetForCurrentMonth(context: context, transactions: transactionVM.transactions, rates: currencyService.rates)

        if settingsVM.settings?.faceIDEnabled == true {
            Task {
                let ok = await settingsVM.authenticate(for: "app")
                if ok { isLocked = false }
            }
        } else {
            isLocked = false
        }

        persistBackup()
    }

    private func handleTransactionsChanged() {
        transactionVM.transactions = transactions
        persistBackup()
    }

    private func handleBudgetsChanged() {
        budgetVM.budgets = budgets
        persistBackup()
    }

    private func handleAccountsChanged() {
        savingsVM.accounts = accounts
        persistBackup()
    }

    private func handleGoalsChanged() {
        savingsVM.goals = goals
        persistBackup()
    }

    private func handleSettingsChanged() {
        if let settings = settingsList.first {
            settingsVM.settings = settings
        }
        persistBackup()
    }

    private func syncFromQueries() {
        settingsVM.load(from: settingsList, context: context)
        transactionVM.transactions = transactions
        budgetVM.budgets = budgets
        savingsVM.accounts = accounts
        savingsVM.goals = goals
    }

    private func syncFromStore() {
        let storedSettings = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? settingsList
        let storedTransactions = (try? context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]))) ?? transactions
        let storedBudgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? budgets
        let storedAccounts = (try? context.fetch(FetchDescriptor<SavingsAccount>())) ?? accounts
        let storedGoals = (try? context.fetch(FetchDescriptor<SavingsGoal>())) ?? goals

        settingsVM.load(from: storedSettings, context: context)
        transactionVM.transactions = storedTransactions
        budgetVM.budgets = storedBudgets
        savingsVM.accounts = storedAccounts
        savingsVM.goals = storedGoals
    }

    private func persistBackup() {
        backupService.saveSnapshot(
            transactions: transactions,
            budgets: budgets,
            accounts: accounts,
            goals: goals,
            categories: categories,
            settings: settingsList
        )
    }

    private var lockScreen: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(accentColor)
            Text("Budgify")
                .font(.largeTitle.bold())
            Button("Déverrouiller") {
                Task {
                    let ok = await settingsVM.authenticate(for: "app")
                    if ok { isLocked = false }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var mainTabView: some View {
        TabView {
            NavigationStack {
                ProtectedTabView(tabName: "Transactions") {
                    TransactionListView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .tabItem { Label("Transactions", systemImage: "list.bullet") }

            NavigationStack {
                ProtectedTabView(tabName: "Budget") {
                    BudgetView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .tabItem { Label("Budget", systemImage: "chart.bar") }

            NavigationStack {
                ProtectedTabView(tabName: "Stats") {
                    StatsView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .tabItem { Label("Stats", systemImage: "chart.pie") }

            NavigationStack {
                ProtectedTabView(tabName: "Savings") {
                    SavingsView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .tabItem { Label("Savings", systemImage: "banknote") }

            NavigationStack {
                ProtectedTabView(tabName: "Catégories") {
                    CategoryListView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .tabItem { Label("Catégories", systemImage: "tag") }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var accentColor: Color {
        Color(hex: settingsVM.settings?.accentColorHex ?? "27AE60")
    }

    private var colorScheme: ColorScheme? {
        switch settingsVM.settings?.backgroundStyle {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
