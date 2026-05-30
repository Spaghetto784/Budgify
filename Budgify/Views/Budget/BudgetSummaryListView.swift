import SwiftUI
import SwiftData

struct BudgetSummaryListView: View {
  @Environment(TransactionViewModel.self) private var transactionVM
  @Environment(CurrencyService.self) private var currencyService
  @Environment(BudgetViewModel.self) private var budgetVM

  @Query(sort: \Budget.startDate, order: .reverse)
  private var budgets: [Budget]

  @Query(sort: \Transaction.date, order: .reverse)
  private var transactions: [Transaction]

  var body: some View {
    List {
      if budgets.isEmpty {
        Text("Aucun budget")
          .foregroundStyle(.secondary)
      } else {
        ForEach(budgets) { budget in
          BudgetSummaryRow(
            budget: budget,
            spent: spent(for: budget),
            remaining: remaining(for: budget),
            currencySymbol: currencyService.symbol(for: budget.currency)
          )
        }
      }
    }
    .onAppear {
      transactionVM.transactions = transactions
      budgetVM.budgets = budgets
    }
  }

  private func spent(for budget: Budget) -> Double {
    let filtered = transactions.filter {
      !$0.isRecurringTemplate &&
      $0.type == .expense &&
      !$0.excludedFromBudget &&
      $0.date >= budget.startDate &&
      $0.date <= budget.endDate
    }
    return filtered.reduce(0.0) { acc, t in
      acc + transactionVM.converted(amount: t.amount, from: t.currency, to: budget.currency, rates: currencyService.rates)
    }
  }

  private func remaining(for budget: Budget) -> Double {
    max(0, budget.limit - spent(for: budget))
  }
}

fileprivate struct BudgetSummaryRow: View {
  let budget: Budget
  let spent: Double
  let remaining: Double
  let currencySymbol: String

  private var progress: Double {
    guard budget.limit > 0 else { return 0 }
    return min(spent / budget.limit, 1)
  }

  private var progressColor: Color {
    switch progress {
    case ..<0.75:
      return .green
    case 0.75..<1:
      return .orange
    default:
      return .red
    }
  }

  private var title: String {
    if budget.name.isEmpty {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "fr_FR")
      formatter.dateFormat = "LLLL yyyy"
      return formatter.string(from: budget.startDate).capitalized
    } else {
      return budget.name
    }
  }

  private var subtitle: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return "\(formatter.string(from: budget.startDate)) – \(formatter.string(from: budget.endDate))"
  }

  private func format(_ value: Double) -> String {
    String(format: "%.0f", value)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("\(currencySymbol) \(format(spent)) / \(format(budget.limit))")
            .font(.headline)
          Text("Restant : \(currencySymbol) \(format(remaining))")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      ProgressView(value: progress)
        .tint(progressColor)
    }
    .padding(.vertical, 6)
  }
}
