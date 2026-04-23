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
    @State private var settingsVM = SettingsViewModel()
    @State private var securityService = SecurityService()
    @State private var backupService = DataBackupService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(currencyService)
                .environment(transactionVM)
                .environment(budgetVM)
                .environment(categoryVM)
                .environment(savingsVM)
                .environment(classifier)
                .environment(settingsVM)
                .environment(securityService)
                .environment(backupService)
                .task { await currencyService.fetchRates() }
        }
        .modelContainer(sharedModelContainer)
    }

    private var sharedModelContainer: ModelContainer {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Budget.self,
            SavingsAccount.self,
            SavingsEntry.self,
            SavingsGoal.self,
            AppSettings.self
        ])

        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeURL = appSupport.appendingPathComponent("Budgify.store")
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to initialize SwiftData store: \(error)")
        }
    }
}
