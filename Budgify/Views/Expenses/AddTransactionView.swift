import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(CategoryClassifier.self) private var classifier
    @Query private var categories: [Category]

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var currency = "EUR"
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var note = ""
    @State private var suggestedCategory: Category?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Dépense").tag(TransactionType.expense)
                        Text("Revenu").tag(TransactionType.income)
                        Text("Prêt").tag(TransactionType.loan)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Titre", text: $title)
                        .onChange(of: title) { _, newValue in
                            if type == .expense {
                                suggestedCategory = classifier.suggest(for: newValue, categories: categories)
                            }
                        }
                    TextField("Montant", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Devise", selection: $currency) {
                        Text("EUR €").tag("EUR")
                        Text("THB ฿").tag("THB")
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if type == .expense {
                    if let suggestion = suggestedCategory, selectedCategory == nil {
                        Section {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.blue)
                                Text("Suggestion : \(suggestion.icon) \(suggestion.name)")
                                Spacer()
                                Button("Appliquer") {
                                    selectedCategory = suggestion
                                    classifier.addTrainingSample(title: title, categoryName: suggestion.name)
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }

                    Section("Catégorie") {
                        if categories.isEmpty {
                            Text("Aucune catégorie")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categories) { cat in
                                HStack {
                                    Text(cat.icon)
                                    Text(cat.name)
                                    Spacer()
                                    if selectedCategory?.id == cat.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let prev = selectedCategory {
                                        classifier.feedback(title: title, predicted: prev.name, actual: cat.name)
                                    }
                                    selectedCategory = cat
                                    classifier.addTrainingSample(title: title, categoryName: cat.name)
                                }
                            }
                        }
                    }
                }

                Section("Note (optionnel)") {
                    TextField("Note", text: $note)
                }
            }
            .navigationTitle("Nouvelle transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !title.isEmpty && Double(amount) != nil
    }

    private func save() {
        guard let amt = Double(amount) else { return }
        let t = Transaction(title: title, amount: amt, date: date, currency: currency, type: type, category: selectedCategory, note: note)
        transactionVM.add(transaction: t, context: context)
        dismiss()
    }
}
