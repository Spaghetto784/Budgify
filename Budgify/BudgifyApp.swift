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
            return try makeContainer(schema: currentSchema, configuration: configuration, storeURL: storeURL)
        } catch {
            fatalError("Unable to initialize SwiftData store: \(error)")
        }
    }

    private func makeContainer(schema: Schema, configuration: ModelConfiguration, storeURL: URL) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            try backupStoreFiles(at: storeURL)
            try purgeStoreFiles(at: storeURL)
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        }
    }

    private func backupStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let recoveryDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("StoreRecovery", isDirectory: true)
        try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let candidates = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]

        for sourceURL in candidates where fileManager.fileExists(atPath: sourceURL.path) {
            let backupURL = recoveryDirectory.appendingPathComponent("\(sourceURL.lastPathComponent).\(stamp).bak")
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: sourceURL, to: backupURL)
        }
    }

    private func purgeStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let urls = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal")
        ]
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
