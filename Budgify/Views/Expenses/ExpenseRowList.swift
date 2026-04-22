import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    let displayCurrency: String
    let rates: [String: Double]

    private var convertedAmount: Double {
        if expense.currency == displayCurrency { return expense.amount }
        if displayCurrency == "THB", let rate = rates["THB"] { return expense.amount * rate }
        if displayCurrency == "EUR", let rate = rates["THB"] { return expense.amount / rate }
        return expense.amount
    }

    private var symbol: String { displayCurrency == "EUR" ? "€" : "฿" }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.body)
                Text(expense.category.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.body.bold())
                Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
