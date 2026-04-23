import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SettingsViewModel.self) private var settingsVM
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]
    @State private var selectedCurrency = "EUR"
    @State private var selectedMonth = Date.now

    private var symbol: String { currencyService.symbol(for: selectedCurrency) }

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    private var monthTransactions: [Transaction] { transactionVM.transactions(for: selectedMonth) }

    private var totalExpenses: Double { transactionVM.total(type: .expense, for: selectedMonth, in: selectedCurrency, rates: currencyService.rates) }
    private var totalIncome: Double { transactionVM.total(type: .income, for: selectedMonth, in: selectedCurrency, rates: currencyService.rates) }
    private var totalLoans: Double { transactionVM.total(type: .loan, for: selectedMonth, in: selectedCurrency, rates: currencyService.rates) }
    private var savings: Double { totalIncome - totalExpenses }

    private var byCategory: [(name: String, icon: String, total: Double, color: String)] {
        categories.compactMap { cat in
            let total = monthTransactions
                .filter { $0.type == .expense && $0.category?.id == cat.id }
                .reduce(0.0) { acc, t in
                    acc + transactionVM.converted(amount: t.amount, from: t.currency, to: selectedCurrency, rates: currencyService.rates)
                }
            if total == 0 { return nil }
            return (name: cat.name, icon: cat.icon, total: total, color: cat.colorHex)
        }
    }

    private var last6Months: [(month: String, expenses: Double, income: Double)] {
        let calendar = Calendar.current
        return (0..<6).compactMap { offset -> (String, Double, Double)? in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: selectedMonth) else { return nil }
            let label = date.formatted(.dateTime.month(.abbreviated))
            let exp = transactionVM.total(type: .expense, for: date, in: selectedCurrency, rates: currencyService.rates)
            let inc = transactionVM.total(type: .income, for: date, in: selectedCurrency, rates: currencyService.rates)
            return (label, exp, inc)
        }.reversed()
    }

    var body: some View {
        List {
            Section {
                DatePicker("Mois", selection: $selectedMonth, displayedComponents: [.date])
                Picker("Devise", selection: $selectedCurrency) {
                    ForEach(displayCurrencies, id: \.self) { code in
                        Text(currencyService.displayLabel(for: code)).tag(code)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Vue d'ensemble") {
                HStack {
                    overviewCard(label: "Revenus", value: totalIncome, color: .green, icon: "arrow.up.circle.fill")
                    overviewCard(label: "Dépenses", value: totalExpenses, color: .red, icon: "arrow.down.circle.fill")
                    overviewCard(label: "Savings", value: savings, color: savings >= 0 ? .blue : .orange, icon: "banknote")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                    Text("Prêts")
                    Spacer()
                    Text("\(symbol)\(String(format: "%.2f", totalLoans))")
                        .bold()
                        .foregroundStyle(.orange)
                }

                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    Text("Transactions")
                    Spacer()
                    Text("\(monthTransactions.count)")
                        .bold()
                }
            }

            if !byCategory.isEmpty {
                Section("Par catégorie") {
                    Chart(byCategory, id: \.name) { item in
                        SectorMark(
                            angle: .value("Total", item.total),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: item.color))
                    }
                    .frame(height: 200)
                    .padding(.vertical, 8)

                    ForEach(byCategory, id: \.name) { item in
                        HStack {
                            Circle()
                                .fill(Color(hex: item.color))
                                .frame(width: 10, height: 10)
                            Text("\(item.icon) \(item.name)")
                            Spacer()
                            Text("\(symbol)\(String(format: "%.2f", item.total))")
                                .bold()
                        }
                    }
                }
            }

            Section("6 derniers mois") {
                Chart(last6Months, id: \.month) { item in
                    BarMark(
                        x: .value("Mois", item.month),
                        y: .value("Dépenses", item.expenses)
                    )
                    .foregroundStyle(.red.opacity(0.8))
                    BarMark(
                        x: .value("Mois", item.month),
                        y: .value("Revenus", item.income)
                    )
                    .foregroundStyle(.green.opacity(0.8))
                }
                .frame(height: 180)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Stats")
        .onAppear {
            transactionVM.transactions = transactions
            selectedCurrency = displayCurrencies.first ?? "EUR"
        }
    }

    private func overviewCard(label: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text("\(symbol)\(String(format: "%.0f", value))")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .padding(.horizontal, 4)
    }
}
