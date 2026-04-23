import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(CategoryClassifier.self) private var classifier
    @Environment(CurrencyService.self) private var currencyService
    @Environment(CategoryViewModel.self) private var categoryVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(SecurityService.self) private var securityService
    @Query private var categories: [Category]

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var currency = "EUR"
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var note = ""
    @State private var suggestedCategory: Category?
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

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
                        ForEach(displayCurrencies, id: \.self) { c in
                            Text(currencyService.displayLabel(for: c)).tag(c)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Récurrence") {
                    Toggle("Transaction récurrente", isOn: $isRecurring)
                    if isRecurring {
                        Picker("Fréquence", selection: $recurrenceFrequency) {
                            Text("Hebdomadaire").tag(RecurrenceFrequency.weekly)
                            Text("Mensuelle").tag(RecurrenceFrequency.monthly)
                        }
                    }
                }

                if type == .expense {
                    if !title.isEmpty, let predictedLabel = classifier.predictedLabel(for: title) {
                        if let matched = suggestedCategory, selectedCategory == nil {
                            Section {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.blue)
                                    Text("\(matched.icon) \(matched.name)")
                                    Spacer()
                                    Button("Appliquer") {
                                        selectedCategory = matched
                                        classifier.addTrainingSample(title: title, categoryName: matched.name)
                                    }
                                    .font(.caption)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                        } else if selectedCategory == nil {
                            Section {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.blue)
                                    Text("Créer \"\(predictedLabel)\"")
                                    Spacer()
                                    Button("Créer") {
                                        let icons = ["Nourriture": "🍔", "Transport": "🚗", "Logement": "🏠", "Loisirs": "🎮", "Santé": "💊", "Shopping": "🛍️", "Éducation": "📚"]
                                        let colors = ["Nourriture": "FF6B6B", "Transport": "45B7D1", "Logement": "96CEB4", "Loisirs": "DDA0DD", "Santé": "98D8C8", "Shopping": "FFEAA7", "Éducation": "4ECDC4"]
                                        let cat = Category(
                                            name: predictedLabel,
                                            colorHex: colors[predictedLabel] ?? "96CEB4",
                                            icon: icons[predictedLabel] ?? "📌"
                                        )
                                        categoryVM.add(category: cat, context: context)
                                        selectedCategory = cat
                                    }
                                    .font(.caption)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
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
                    if settingsVM.settings?.dataEncryptionEnabled == true {
                        Label("Cette note sera chiffrée (AES-256)", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            .onAppear {
                currency = displayCurrencies.first ?? "EUR"
            }
        }
    }

    private var isValid: Bool {
        !title.isEmpty && Double(amount) != nil
    }

    private func save() {
        guard let amt = Double(amount) else { return }

        let shouldEncrypt = settingsVM.settings?.dataEncryptionEnabled == true
        let noteHash = note.isEmpty ? nil : securityService.hash(note)
        let ciphertext = shouldEncrypt ? securityService.encrypt(note) : nil
        let storedNote = (shouldEncrypt && ciphertext != nil) ? "" : note

        let transaction = Transaction(
            title: title,
            amount: amt,
            date: date,
            currency: currency,
            type: type,
            category: selectedCategory,
            note: storedNote,
            noteCiphertext: ciphertext,
            noteHash: noteHash
        )

        transactionVM.add(transaction: transaction, context: context)

        if type == .expense, let selectedCategory {
            classifier.addTrainingSample(title: title, categoryName: selectedCategory.name)
        }

        if isRecurring {
            transactionVM.addRecurringTemplate(from: transaction, frequency: recurrenceFrequency, context: context)
        }

        dismiss()
    }
}
