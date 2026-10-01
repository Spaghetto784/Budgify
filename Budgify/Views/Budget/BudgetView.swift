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
    @State private var selectedDate = Date.now
    @State private var showAdd = false
    @State private var showAdjustLimit = false
    @State private var adjustAmount = ""
    @State private var isIncrease = true
    @State private var showSummary = false
    @State private var animateProgress = false
    @Namespace private var animation

    private var currentBudget: Budget? { budgetVM.budget(containing: selectedDate) }
    private var symbol: String { currentBudget.map { currencyService.symbol(for: $0.currency) } ?? "€" }
    private var currency: String { currentBudget?.currency ?? "EUR" }

    private var spent: Double {
        guard let budget = currentBudget else { return 0 }
        return transactionVM.transactions(from: budget.startDate, to: budget.endDate)
            .filter { $0.type == .expense && !$0.excludedFromBudget }
            .reduce(0) { acc, transaction in
                acc + transactionVM.converted(amount: transaction.amount, from: transaction.currency, to: currency, rates: currencyService.rates)
            }
    }

    private var income: Double {
        guard let budget = currentBudget else { return 0 }
        return transactionVM.total(type: .income, from: budget.startDate, to: budget.endDate, in: currency, rates: currencyService.rates)
    }

    private var remaining: Double { (currentBudget?.limit ?? 0) - spent }

    private var progress: Double {
        guard let limit = currentBudget?.limit, limit > 0 else { return 0 }
        return min(spent / limit, 1.0)
    }

    private var periodTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }
        return transactionVM.transactions(from: budget.startDate, to: budget.endDate).filter { $0.type == .expense && !$0.excludedFromBudget }
    }

    private var alertMessage: String? {
        guard let budget = currentBudget else { return nil }
        return budgetVM.alertMessage(for: budget, spent: spent)
    }

    private var projectedOverrunDays: Int? {
        guard let budget = currentBudget else { return nil }
        return budgetVM.projectedOverrunInDays(for: budget, spent: spent)
    }

    var body: some View {
        List {
            Section {
                DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
            }

            if let budget = currentBudget {
                Section("Période") {
                    Text("Du \(budget.startDate.formatted(date: .abbreviated, time: .omitted)) au \(budget.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Vue d'ensemble") {
                    VStack(spacing: 16) {
                        // Circular progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                                .frame(width: 200, height: 200)
                            
                            Circle()
                                .trim(from: 0, to: animateProgress ? progress : 0)
                                .stroke(
                                    progress > 0.9 ? .red :
                                    progress > 0.7 ? .orange : .green,
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(duration: 1.0, bounce: 0.3), value: animateProgress)
                            
                            VStack(spacing: 4) {
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 42, weight: .bold))
                                    .contentTransition(.numericText())
                                Text("utilisé")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Dépensé", systemImage: "arrow.down.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(symbol)\(String(format: "%.2f", spent))")
                                    .font(.title3.bold())
                                    .foregroundStyle(.red)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.red.opacity(0.1))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Restant", systemImage: "banknote.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(symbol)\(String(format: "%.2f", remaining))")
                                    .font(.title3.bold())
                                    .foregroundStyle(remaining < 0 ? .red : .green)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((remaining < 0 ? Color.red : .green).opacity(0.1))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Limite", systemImage: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(symbol)\(String(format: "%.2f", budget.limit))")
                                .font(.title3.bold())
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.1))
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)

                    if budget.rolloverFromPreviousMonth > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.blue)
                                .imageScale(.large)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Report de la période précédente")
                                    .font(.subheadline)
                                Text("+\(symbol)\(String(format: "%.2f", budget.rolloverFromPreviousMonth))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(symbol)\(String(format: "%.2f", budget.rolloverFromPreviousMonth))")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.1))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                Section("Ajustement") {
                    Button {
                        adjustAmount = ""
                        isIncrease = true
                        showAdjustLimit = true
                    } label: {
                        Label("Ajuster le budget", systemImage: "arrow.up.arrow.down.circle.fill")
                    }
                }

                if let alertMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .imageScale(.large)
                                Text(alertMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                            
                            if let projectedOverrunDays, projectedOverrunDays > 0 {
                                Divider()
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundStyle(.orange)
                                    Text("Dépassement estimé dans \(projectedOverrunDays) jour\(projectedOverrunDays > 1 ? "s" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.orange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                    } header: {
                        Label("Alertes", systemImage: "bell.badge.fill")
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if let projectedOverrunDays, projectedOverrunDays > 0 {
                    Section {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.blue)
                            Text("Dépassement estimé dans \(projectedOverrunDays) jour\(projectedOverrunDays > 1 ? "s" : "")")
                                .font(.subheadline)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.1))
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.horizontal)
                    } header: {
                        Label("Prévision", systemImage: "crystal.ball")
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Section("Revenus") {
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

                Section("Dépenses (\(periodTransactions.count))") {
                    if periodTransactions.isEmpty {
                        Text("Aucune dépense sur cette période")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(periodTransactions) { t in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).font(.body)
                                    if let name = t.resolvedCategoryName {
                                        Text("\(t.resolvedCategoryIcon ?? "📌") \(name)")
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
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if !t.excludedFromBudget {
                                    Button {
                                        t.excludedFromBudget = true
                                        try? context.save()
                                    } label: {
                                        Label("Retirer du budget", systemImage: "xmark.circle.fill")
                                    }
                                    .tint(.orange)
                                } else {
                                    Button {
                                        t.excludedFromBudget = false
                                        try? context.save()
                                    } label: {
                                        Label("Inclure au budget", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.green)
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
                        Text("Aucun budget pour cette date")
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showSummary = true } label: {
                    Image(systemName: "rectangle.stack")
                }
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBudgetView()
        }
        .sheet(isPresented: $showAdjustLimit) {
            adjustLimitSheet
        }
        .sheet(isPresented: $showSummary) {
            BudgetSummaryListView()
        }
        .onAppear {
            budgetVM.budgets = budgets
            transactionVM.transactions = transactions
            budgetVM.ensureRecurringBudgetForCurrentMonth(context: context, transactions: transactions, rates: currencyService.rates)
            triggerBudgetNotificationIfNeeded()
            withAnimation(.spring(duration: 1.0, bounce: 0.3).delay(0.2)) {
                animateProgress = true
            }
        }
        .onChange(of: selectedDate) { _, _ in
            budgetVM.budgets = budgets
            triggerBudgetNotificationIfNeeded()
            animateProgress = false
            withAnimation(.spring(duration: 1.0, bounce: 0.3).delay(0.1)) {
                animateProgress = true
            }
        }
        .onChange(of: budgets.count) { _, _ in
            budgetVM.budgets = budgets
            triggerBudgetNotificationIfNeeded()
        }
        .onChange(of: transactions.count) { _, _ in
            transactionVM.transactions = transactions
            triggerBudgetNotificationIfNeeded()
        }
        .animation(.smooth, value: spent)
        .animation(.smooth, value: remaining)
    }

    private func triggerBudgetNotificationIfNeeded() {
        guard settingsVM.settings?.budgetAlertsEnabled == true, let budget = currentBudget else { return }
        budgetVM.notifyIfNeeded(for: budget, spent: spent)
    }

    private var adjustLimitSheet: some View {
        NavigationStack {
            Form {
                Section("Type d'ajustement") {
                    Picker("Action", selection: $isIncrease) {
                        Text("Augmenter").tag(true)
                        Text("Diminuer").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section(isIncrease ? "Montant à ajouter" : "Montant à retirer") {
                    TextField("Montant", text: $adjustAmount)
                        .keyboardType(.decimalPad)
                    if let budget = currentBudget {
                        Text("Limite actuelle: \(currencyService.symbol(for: budget.currency))\(String(format: "%.2f", budget.limit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ajuster budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        showAdjustLimit = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Valider") {
                        applyAdjustLimit()
                    }
                    .disabled(NumberParsing.parseDouble(adjustAmount) == nil)
                }
            }
        }
    }

    private func applyAdjustLimit() {
        guard let budget = currentBudget, let amount = NumberParsing.parseDouble(adjustAmount), amount > 0 else { return }
        if isIncrease {
            budgetVM.increaseLimit(for: budget, by: amount, context: context)
        } else {
            budgetVM.decreaseLimit(for: budget, by: amount, context: context)
        }
        showAdjustLimit = false
    }
}
