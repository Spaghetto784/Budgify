import Foundation

/// Represents a portion of a transaction attributed to a specific category (by name).
/// Use `amount` to express the share in the transaction currency.
struct CategorySplit: Codable, Hashable, Identifiable {
    var id: UUID
    var categoryName: String
    var amount: Double

    init(id: UUID = UUID(), categoryName: String, amount: Double) {
        self.id = id
        self.categoryName = categoryName
        self.amount = amount
    }
}

/// Utilities to work with splits
enum SplitAllocator {
    /// Normalizes splits so that the sum of amounts equals the transaction amount.
    /// If the sum is 0 or invalid, returns a single split using the first category (if any).
    static func normalize(splits: [CategorySplit], to total: Double) -> [CategorySplit] {
        guard total != 0, !splits.isEmpty else { return splits }
        let positiveTotal = abs(total)
        let sum = splits.map { abs($0.amount) }.reduce(0, +)
        guard sum > 0 else {
            var copy = splits
            copy[0].amount = total
            return copy
        }
        return splits.map { split in
            let ratio = abs(split.amount) / sum
            var s = split
            s.amount = (total.sign == .minus ? -1 : 1) * ratio * positiveTotal
            return s
        }
    }
}
