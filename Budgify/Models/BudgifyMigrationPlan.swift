import SwiftData

enum BudgifyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BudgifySchemaV1.self, BudgifySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: BudgifySchemaV1.self, toVersion: BudgifySchemaV2.self)
        ]
    }
}
