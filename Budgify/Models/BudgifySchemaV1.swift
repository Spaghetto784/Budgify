import SwiftData

enum BudgifySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

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
