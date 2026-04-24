import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let displayCurrency: String
    let rates: [String: Double]

    private var convertedAmount: Double {
        convert(amount: transaction.amount, from: transaction.currency, to: displayCurrency)
    }

    private var symbol: String {
        let symbols: [String: String] = [
            "EUR": "€", "USD": "$", "GBP": "£", "JPY": "¥", "CHF": "Fr",
            "CAD": "C$", "AUD": "A$", "CNY": "¥", "INR": "₹", "SGD": "S$", "THB": "฿"
        ]
        return symbols[displayCurrency] ?? ""
    }

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

                if let name = transaction.resolvedCategoryName {
                    let icon = transaction.resolvedCategoryIcon ?? "📌"
                    Text("\(icon) \(name)")
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

    private func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        if from == "EUR" {
            return amount * (rates[to] ?? 1)
        }
        if to == "EUR" {
            return amount / (rates[from] ?? 1)
        }
        let inEUR = amount / (rates[from] ?? 1)
        return inEUR * (rates[to] ?? 1)
    }
}
