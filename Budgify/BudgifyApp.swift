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
    @State private var expensePDFService = ExpensePDFService()

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
                .environment(expensePDFService)
                .task { await currencyService.fetchRates() }
        }
        .modelContainer(sharedModelContainer)
    }

    private var sharedModelContainer: ModelContainer {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let storeURL = appSupport.appendingPathComponent("Budgify.store")
            let currentSchema = Schema(BudgifySchemaV2.models)
            let configuration = ModelConfiguration(schema: currentSchema, url: storeURL)
            return try ModelContainer(
                for: currentSchema,
                migrationPlan: BudgifyMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to initialize SwiftData store: \(error)")
        }
    }
}
