import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(ExpensePDFService.self) private var expensePDFService

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var showAdd = false
    @State private var selectedCurrency = "EUR"
    @State private var selectedType: TransactionType? = nil
    @State private var selectedMonth = Date.now
    @State private var pdfURL: URL?
    @State private var searchText = ""
    @State private var showFilters = false
    @Namespace private var animation

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    private var filtered: [Transaction] {
        let calendar = Calendar.current
        var monthFiltered = transactions.filter {
            !$0.isRecurringTemplate &&
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }

        // Search filter
        if !searchText.isEmpty {
            monthFiltered = monthFiltered.filter { transaction in
                transaction.title.localizedCaseInsensitiveContains(searchText) ||
                transaction.note.localizedCaseInsensitiveContains(searchText) ||
                transaction.resolvedCategoryName?.localizedCaseInsensitiveContains(searchText) == true ||
                transaction.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        guard let type = selectedType else { return monthFiltered }
        return monthFiltered.filter { $0.type == type }
    }
    
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
    }
    
    private var totalForMonth: Double {
        filtered.reduce(0) { acc, transaction in
            let converted = transactionVM.converted(
                amount: transaction.amount,
                from: transaction.currency,
                to: selectedCurrency,
                rates: currencyService.rates
            )
            switch transaction.type {
            case .expense: return acc - converted
            case .income: return acc + converted
            case .loan: return acc
            }
        }
    }

    private var monthExpenses: [Transaction] {
        let calendar = Calendar.current
        return transactions.filter {
            !$0.isRecurringTemplate &&
            $0.type == .expense &&
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    var body: some View {
        List {
            Section {
                // Month selector with animation
                HStack {
                    Button {
                        withAnimation(.smooth) {
                            selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.headline)
                        Text("\(filtered.count) transaction\(filtered.count > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentTransition(.numericText())
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.smooth) {
                            selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 8)

                // Summary card with animation
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Balance du mois")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currencyService.symbol(for: selectedCurrency) + String(format: "%.2f", totalForMonth))
                                .font(.title.bold())
                                .foregroundStyle(totalForMonth >= 0 ? .green : .red)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.thinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal)

                // Filters with improved design
                HStack(spacing: 12) {
                    Picker("Devise", selection: $selectedCurrency) {
                        ForEach(displayCurrencies, id: \.self) { c in
                            Text(currencyService.displayLabel(for: c)).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.blue)
                    
                    Button {
                        withAnimation(.smooth) {
                            showFilters.toggle()
                        }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                if showFilters {
                    Picker("Type", selection: $selectedType) {
                        Text("Tout").tag(Optional<TransactionType>.none)
                        Text("Dépenses").tag(Optional<TransactionType>.some(.expense))
                        Text("Revenus").tag(Optional<TransactionType>.some(.income))
                        Text("Prêts").tag(Optional<TransactionType>.some(.loan))
                    }
                    .pickerStyle(.segmented)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Grouped transactions by day
            ForEach(groupedTransactions, id: \.date) { group in
                Section {
                    ForEach(group.transactions) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRowView(
                                transaction: transaction,
                                displayCurrency: selectedCurrency,
                                rates: currencyService.rates
                            )
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    .onDelete { indexSet in
                        withAnimation {
                            indexSet.forEach { transactionVM.delete(transaction: group.transactions[$0], context: context) }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.date.formatted(.dateTime.day().month().weekday(.wide)))
                            .font(.subheadline.bold())
                        Spacer()
                        let dayTotal = group.transactions.reduce(0.0) { acc, t in
                            let converted = transactionVM.converted(
                                amount: t.amount,
                                from: t.currency,
                                to: selectedCurrency,
                                rates: currencyService.rates
                            )
                            return acc + (t.type == .expense ? -converted : converted)
                        }
                        Text(currencyService.symbol(for: selectedCurrency) + String(format: "%.2f", dayTotal))
                            .font(.caption.bold())
                            .foregroundStyle(dayTotal >= 0 ? .green : .red)
                    }
                }
            }
            
            if filtered.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "Aucune transaction pour ce mois" : "Aucun résultat")
                            .foregroundStyle(.secondary)
                        if !searchText.isEmpty {
                            Button("Effacer la recherche") {
                                searchText = ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                .listRowBackground(Color.clear)
            }
        }
        .searchable(text: $searchText, prompt: "Rechercher transactions...")
        .animation(.smooth, value: filtered.count)
        .animation(.smooth, value: selectedType)
        .animation(.smooth, value: showFilters)
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if transactionVM.canUndoDelete {
                    Button {
                        withAnimation {
                            transactionVM.undoLastDelete(context: context)
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    exportPDF()
                } label: {
                    Image(systemName: "doc.text")
                }

                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            transactionVM.transactions = transactions
            transactionVM.generateDueRecurringTransactions(context: context)
            selectedCurrency = displayCurrencies.first ?? "EUR"
        }
        .onChange(of: transactions.count) { _, _ in
            transactionVM.transactions = transactions
        }
    }

    private func exportPDF() {
        pdfURL = expensePDFService.exportMonthlyExpensesPDF(
            transactions: monthExpenses,
            month: selectedMonth,
            displayCurrency: selectedCurrency,
            rates: currencyService.rates,
            symbolProvider: currencyService.symbol(for:)
        )
    }
}
