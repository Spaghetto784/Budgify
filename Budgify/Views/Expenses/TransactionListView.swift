import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService
    @Environment(TransactionViewModel.self) private var transactionVM
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showAdd = false
    @State private var selectedCurrency = "EUR"
    @State private var selectedType: TransactionType? = nil

    private var filtered: [Transaction] {
        guard let type = selectedType else { return transactions }
        return transactions.filter { $0.type == type }
    }

    private var symbol: String { selectedCurrency == "EUR" ? "€" : "฿" }

    var body: some View {
        List {
            Section {
                Picker("", selection: $selectedCurrency) {
                    Text("EUR €").tag("EUR")
                    Text("THB ฿").tag("THB")
                }
                .pickerStyle(.segmented)

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
                    Text("Aucune transaction")
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
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView()
        }
        .onAppear { transactionVM.transactions = transactions }
    }
}
