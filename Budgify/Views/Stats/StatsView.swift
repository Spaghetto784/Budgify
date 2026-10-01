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
    @State private var categoryChartStyle: Int = 0 // 0 = camembert, 1 = barres
    @State private var animateCharts = false
    @Namespace private var animation

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
                .filter { $0.type == .expense && !$0.excludedFromBudget && $0.resolvedCategoryName == cat.name }
                .reduce(0.0) { acc, t in
                    acc + transactionVM.converted(amount: t.amount, from: t.currency, to: selectedCurrency, rates: currencyService.rates)
                }
            if total == 0 { return nil }
            return (name: cat.name, icon: cat.icon, total: total, color: cat.colorHex)
        }
    }

    private var categoryAlerts: [(name: String, icon: String, spent: Double, ratio: Double)] {
        let trackedExpenses = byCategory.reduce(0.0) { $0 + $1.total }
        guard trackedExpenses > 0 else { return [] }
        return byCategory
            .map { item in
                (name: item.name, icon: item.icon, spent: item.total, ratio: item.total / trackedExpenses)
            }
            .filter { $0.ratio >= 0.30 }
            .sorted { $0.spent > $1.spent }
    }

    private var subscriptions: [SubscriptionInsight] {
        transactionVM.subscriptionInsights(for: selectedMonth, in: selectedCurrency, rates: currencyService.rates)
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
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        overviewCard(label: "Revenus", value: totalIncome, color: .green, icon: "arrow.up.circle.fill")
                        Divider()
                        overviewCard(label: "Dépenses", value: totalExpenses, color: .red, icon: "arrow.down.circle.fill")
                    }
                    
                    Divider()
                    
                    HStack(spacing: 0) {
                        overviewCard(label: "Savings", value: savings, color: savings >= 0 ? .blue : .orange, icon: "banknote.fill")
                        Divider()
                        overviewCard(label: "Prêts", value: totalLoans, color: .orange, icon: "arrow.triangle.2.circlepath")
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal)
                .scaleEffect(animateCharts ? 1 : 0.8)
                .opacity(animateCharts ? 1 : 0)

                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    Text("Transactions")
                    Spacer()
                    Text("\(monthTransactions.count)")
                        .bold()
                        .contentTransition(.numericText())
                }
            }

            if !byCategory.isEmpty {
                Section {
                    Picker("Style", selection: $categoryChartStyle) {
                        Label("Camembert", systemImage: "chart.pie.fill").tag(0)
                        Label("Barres", systemImage: "chart.bar.fill").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if categoryChartStyle == 0 {
                        Chart(byCategory, id: \.name) { item in
                            SectorMark(
                                angle: .value("Total", animateCharts ? item.total : 0),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(Color(hex: item.color))
                            .annotation(position: .overlay) {
                                if item.total > totalExpenses * 0.1 {
                                    Text(item.icon)
                                        .font(.title2)
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding(.vertical, 8)
                        .chartBackground { _ in
                            VStack {
                                Text(symbol + String(format: "%.0f", totalExpenses))
                                    .font(.title2.bold())
                                    .contentTransition(.numericText())
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Chart(byCategory.sorted { $0.total > $1.total }, id: \.name) { item in
                            BarMark(
                                x: .value("Total", animateCharts ? item.total : 0),
                                y: .value("Catégorie", item.name)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: item.color), Color(hex: item.color).opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .annotation(position: .trailing, spacing: 8) {
                                Text(symbol + String(format: "%.0f", item.total))
                                    .font(.caption.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(height: max(250, CGFloat(byCategory.count) * 50))
                        .padding(.vertical, 8)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let name = value.as(String.self),
                                       let item = byCategory.first(where: { $0.name == name }) {
                                        Text("\(item.icon) \(name)")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }

                    ForEach(byCategory.sorted { $0.total > $1.total }, id: \.name) { item in
                        HStack {
                            Circle()
                                .fill(Color(hex: item.color))
                                .frame(width: 12, height: 12)
                            Text("\(item.icon) \(item.name)")
                                .font(.subheadline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(symbol)\(String(format: "%.2f", item.total))")
                                    .bold()
                                Text("\(Int((item.total / totalExpenses) * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Label("Dépenses par catégorie", systemImage: "chart.pie")
                }
            }

            if !categoryAlerts.isEmpty {
                Section("Alertes catégorie") {
                    ForEach(categoryAlerts, id: \.name) { alert in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(alert.icon) \(alert.name)")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(symbol)\(String(format: "%.2f", alert.spent))")
                                    .bold()
                                Text("\(Int(alert.ratio * 100))% des dépenses")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !subscriptions.isEmpty {
                Section("Abonnements intelligents") {
                    ForEach(subscriptions) { sub in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sub.title)
                                .font(.headline)
                            HStack {
                                Text("Mensuel estimé")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(symbol)\(String(format: "%.2f", sub.monthlyEstimate))")
                                    .bold()
                            }
                            HStack {
                                Text("Annuel estimé")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(symbol)\(String(format: "%.2f", sub.annualEstimate))")
                                    .bold()
                            }
                            Text("\(sub.occurrences) occurrence(s) détectée(s)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
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
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.1)) {
                animateCharts = true
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            animateCharts = false
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.1)) {
                animateCharts = true
            }
        }
        .animation(.smooth, value: categoryChartStyle)
    }

    private func overviewCard(label: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
                .imageScale(.large)
            Text("\(symbol)\(String(format: "%.0f", value))")
                .font(.title3.bold())
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
