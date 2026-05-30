import SwiftData
import Foundation

@Observable
final class RecurringService {
    /// Mark a specific day for a recurring series as skipped.
    func skipOccurrence(seriesKey: String, on date: Date, context: ModelContext) {
        let day = Calendar.current.startOfDay(for: date)
        // Check if already exists
        var descriptor = FetchDescriptor<RecurringException>(
            predicate: #Predicate<RecurringException> { $0.key == seriesKey && $0.day == day }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor), existing.first != nil {
            return
        }
        let exception = RecurringException(key: seriesKey, day: day)
        context.insert(exception)
        try? context.save()
    }

    /// Returns true if the given day is marked as skipped for the series.
    func isSkipped(seriesKey: String, on date: Date, context: ModelContext) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        var descriptor = FetchDescriptor<RecurringException>(
            predicate: #Predicate<RecurringException> { $0.key == seriesKey && $0.day == day }
        )
        descriptor.fetchLimit = 1
        let found = (try? context.fetch(descriptor)) ?? []
        return !found.isEmpty
    }
}
