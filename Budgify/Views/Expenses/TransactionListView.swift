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

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    private var filtered: [Transaction] {
        let calendar = Calendar.current
        let monthFiltered = transactions.filter {
            !$0.isRecurringTemplate &&
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }

        guard let type = selectedType else { return monthFiltered }
        return monthFiltered.filter { $0.type == type }
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
                DatePicker("Mois", selection: $selectedMonth, displayedComponents: [.date])
                    .datePickerStyle(.compact)

                Picker("Devise", selection: $selectedCurrency) {
                    ForEach(displayCurrencies, id: \.self) { c in
                        Text(currencyService.displayLabel(for: c)).tag(c)
                    }
                }
                .pickerStyle(.menu)

                Picker("Type", selection: $selectedType) {
                    Text("Tout").tag(Optional<TransactionType>.none)
                    Text("Dépenses").tag(Optional<TransactionType>.some(.expense))
                    Text("Revenus").tag(Optional<TransactionType>.some(.income))
                    Text("Prêts").tag(Optional<TransactionType>.some(.loan))
                }
                .pickerStyle(.segmented)
            }

            Section("Transactions") {
                if filtered.isEmpty {
                    Text("Aucune transaction pour ce mois")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRowView(transaction: transaction, displayCurrency: selectedCurrency, rates: currencyService.rates)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { transactionVM.delete(transaction: filtered[$0], context: context) }
                    }
                }
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
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
