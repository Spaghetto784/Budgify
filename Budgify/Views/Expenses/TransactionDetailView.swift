import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    @Environment(TransactionViewModel.self) private var transactionVM
    let transaction: Transaction
    @State private var selectedCurrency: String

    init(transaction: Transaction) {
        self.transaction = transaction
        _selectedCurrency = State(initialValue: transaction.currency)
    }

    private var convertedAmount: Double {
        if transaction.currency == selectedCurrency { return transaction.amount }
        if selectedCurrency == "THB", let rate = currencyService.rates["THB"] { return transaction.amount * rate }
        if selectedCurrency == "EUR", let rate = currencyService.rates["THB"] { return transaction.amount / rate }
        return transaction.amount
    }

    private var symbol: String { selectedCurrency == "EUR" ? "€" : "฿" }

    private var typeLabel: String {
        switch transaction.type {
        case .expense: return "Dépense"
        case .income: return "Revenu"
        case .loan: return "Prêt"
        }
    }

    private var typeColor: Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .loan: return .orange
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    if let cat = transaction.category {
                        Text(cat.icon).font(.largeTitle)
                    }
                    VStack(alignment: .leading) {
                        Text(transaction.title).font(.title3.bold())
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundStyle(typeColor)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Montant") {
                Picker("", selection: $selectedCurrency) {
                    Text("EUR €").tag("EUR")
                    Text("THB ฿").tag("THB")
                }
                .pickerStyle(.segmented)
                Text("\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.title.bold())
                    .foregroundStyle(typeColor)
            }

            Section("Date") {
                Text(transaction.date.formatted(date: .long, time: .omitted))
            }

            if !transaction.note.isEmpty {
                Section("Note") {
                    Text(transaction.note)
                }
            }

            if let cat = transaction.category {
                Section("Catégorie") {
                    HStack {
                        Text(cat.icon)
                        Text(cat.name)
                        Spacer()
                        Circle()
                            .fill(Color(hex: cat.colorHex))
                            .frame(width: 16, height: 16)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    transactionVM.delete(transaction: transaction, context: context)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Supprimer")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
