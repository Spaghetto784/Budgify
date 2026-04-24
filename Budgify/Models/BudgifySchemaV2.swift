import SwiftData

enum BudgifySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Transaction.self,
            Category.self,
            Budget.self,
            SavingsAccount.self,
            SavingsEntry.self,
            SavingsGoal.self,
            AppSettings.self
        ]
    }
}
