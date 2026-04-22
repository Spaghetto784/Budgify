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
        context.delete(category)
        try? context.save()
    }
}
