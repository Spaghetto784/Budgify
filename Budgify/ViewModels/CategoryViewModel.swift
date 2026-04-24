import SwiftData
import Foundation

@Observable
final class CategoryViewModel {
    var categories: [Category] = []

    func add(category: Category, context: ModelContext) {
        context.insert(category)
        try? context.save()
    }

    func delete(category: Category, context: ModelContext) {
        if let transactions = try? context.fetch(FetchDescriptor<Transaction>()) {
            for transaction in transactions where transaction.categoryNameSnapshot == category.name {
                transaction.categoryIconSnapshot = category.icon
                transaction.categoryColorHexSnapshot = category.colorHex
                transaction.category = nil
            }
        }

        context.delete(category)
        try? context.save()
    }
}
