import SwiftData
import Foundation

@Model
final class RecurringException {
    var key: String      // Identifier of the recurring series
    var day: Date        // Normalized date (startOfDay)

    init(key: String, day: Date) {
        self.key = key
        self.day = Calendar.current.startOfDay(for: day)
    }
}
