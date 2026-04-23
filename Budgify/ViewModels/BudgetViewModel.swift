import SwiftData
import Foundation

@Observable
final class BudgetViewModel {
    var budgets: [Budget] = []

    func add(budget: Budget, context: ModelContext) {
        context.insert(budget)
        try? context.save()
    }

    func update(context: ModelContext) {
        try? context.save()
    }

    func delete(budget: Budget, context: ModelContext) {
        context.delete(budget)
        try? context.save()
    }

    func budget(for month: Date) -> Budget? {
        let calendar = Calendar.current
        return budgets.first {
            calendar.isDate($0.month, equalTo: month, toGranularity: .month)
        }
    }
}
