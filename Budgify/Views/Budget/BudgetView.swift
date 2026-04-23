import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(BudgetViewModel.self) private var budgetVM
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SettingsViewModel.self) private var settingsVM
    @Query private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var selectedMonth = Date.now
    @State private var showAdd = false

    private var currentBudget: Budget? { budgetVM.budget(for: selectedMonth) }
    private var symbol: String { currentBudget.map { currencyService.symbol(for: $0.currency) } ?? "€" }
    private var currency: String { currentBudget?.currency ?? "EUR" }

    private var spent: Double {
        transactionVM.total(type: .expense, for: selectedMonth, in: currency, rates: currencyService.rates)
    }

    private var income: Double {
        transactionVM.total(type: .income, for: selectedMonth, in: currency, rates: currencyService.rates)
    }

    private var remaining: Double { (currentBudget?.limit ?? 0) - spent }

    private var progress: Double {
        guard let limit = currentBudget?.limit, limit > 0 else { return 0 }
        return min(spent / limit, 1.0)
    }

    private var monthTransactions: [Transaction] {
        transactionVM.transactions(for: selectedMonth).filter { $0.type == .expense }
    }

    private var alertMessage: String? {
        guard let budget = currentBudget else { return nil }
        return budgetVM.alertMessage(for: budget, spent: spent)
    }

    private var projectedOverrunDays: Int? {
        guard let budget = currentBudget else { return nil }
        return budgetVM.projectedOverrunInDays(for: budget, spent: spent, month: selectedMonth)
    }

    var body: some View {
        List {
            Section {
                DatePicker("Mois", selection: $selectedMonth, displayedComponents: [.date])
                    .datePickerStyle(.compact)
            }

            if let budget = currentBudget {
                Section("Vue d'ensemble") {
                    VStack(spacing: 12) {
                        ProgressView(value: progress)
                            .tint(progress > 0.9 ? .red : progress > 0.7 ? .orange : .green)
                            .scaleEffect(x: 1, y: 2)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Dépensé")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(symbol)\(String(format: "%.2f", spent))")
                                    .font(.headline)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                            VStack(alignment: .center, spacing: 2) {
                                Text("Restant")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(symbol)\(String(format: "%.2f", remaining))")
                                    .font(.headline)
                                    .foregroundStyle(remaining < 0 ? .red : .green)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Limite")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(symbol)\(String(format: "%.2f", budget.limit))")
                                    .font(.headline)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if budget.rolloverFromPreviousMonth > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.blue)
                            Text("Report du mois précédent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\(symbol)\(String(format: "%.2f", budget.rolloverFromPreviousMonth))")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                        }
                    }
                }

                if let alertMessage {
                    Section("Alertes") {
                        Label(alertMessage, systemImage: "bell.badge.fill")
                            .foregroundStyle(.orange)
                        if let projectedOverrunDays, projectedOverrunDays > 0 {
                            Text("Au rythme actuel, dépassement estimé dans \(projectedOverrunDays) jour(s).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let projectedOverrunDays, projectedOverrunDays > 0 {
                    Section("Prévision") {
                        Text("Au rythme actuel, dépassement estimé dans \(projectedOverrunDays) jour(s).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Revenus du mois") {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                        Text("Total revenus")
                        Spacer()
                        Text("\(symbol)\(String(format: "%.2f", income))")
                            .bold()
                            .foregroundStyle(.green)
                    }
                }

                Section("Dépenses (\(monthTransactions.count))") {
                    if monthTransactions.isEmpty {
                        Text("Aucune dépense ce mois")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(monthTransactions) { t in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).font(.body)
                                    if let cat = t.category {
                                        Text("\(cat.icon) \(cat.name)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("-\(symbol)\(String(format: "%.2f", transactionVM.converted(amount: t.amount, from: t.currency, to: currency, rates: currencyService.rates)))")
                                        .foregroundStyle(.red)
                                        .font(.body.bold())
                                    Text("\(Int((transactionVM.converted(amount: t.amount, from: t.currency, to: currency, rates: currencyService.rates) / budget.limit) * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        budgetVM.delete(budget: budget, context: context)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Supprimer ce budget")
                            Spacer()
                        }
                    }
                }

            } else {
                Section {
                    VStack(spacing: 8) {
                        Text("Aucun budget pour ce mois")
                            .foregroundStyle(.secondary)
                        Button("Créer un budget") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBudgetView()
        }
        .onAppear {
            budgetVM.budgets = budgets
            transactionVM.transactions = transactions
            budgetVM.ensureRecurringBudgetForCurrentMonth(context: context, transactions: transactions, rates: currencyService.rates)
            triggerBudgetNotificationIfNeeded()
        }
        .onChange(of: selectedMonth) { _, _ in
            budgetVM.budgets = budgets
            triggerBudgetNotificationIfNeeded()
        }
        .onChange(of: budgets.count) { _, _ in
            budgetVM.budgets = budgets
            triggerBudgetNotificationIfNeeded()
        }
        .onChange(of: transactions.count) { _, _ in
            transactionVM.transactions = transactions
            triggerBudgetNotificationIfNeeded()
        }
    }

    private func triggerBudgetNotificationIfNeeded() {
        guard settingsVM.settings?.budgetAlertsEnabled == true, let budget = currentBudget else { return }
        budgetVM.notifyIfNeeded(for: budget, spent: spent, month: selectedMonth)
    }
}
