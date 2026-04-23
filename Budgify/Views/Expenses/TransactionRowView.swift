import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let displayCurrency: String
    let rates: [String: Double]

    private var convertedAmount: Double {
        if transaction.currency == displayCurrency { return transaction.amount }
        if displayCurrency == "THB", let rate = rates["THB"] { return transaction.amount * rate }
        if displayCurrency == "EUR", let rate = rates["THB"] { return transaction.amount / rate }
        return transaction.amount
    }

    private var symbol: String { displayCurrency == "EUR" ? "€" : "฿" }

    private var typeColor: Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .loan: return .orange
        }
    }

    private var typeIcon: String {
        switch transaction.type {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .loan: return "clock.arrow.circlepath"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon)
                .foregroundStyle(typeColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                if let cat = transaction.category {
                    Text("\(cat.icon) \(cat.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .expense ? "-" : "+")\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.body.bold())
                    .foregroundStyle(typeColor)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
