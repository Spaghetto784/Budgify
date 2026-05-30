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
    @Environment(SavingsViewModel.self) private var savingsVM
    @Query private var categories: [Category]
    @Query private var savingsAccounts: [SavingsAccount]

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var currency = "EUR"
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var excludeFromBudget = false
    @State private var note = ""
    @State private var suggestedCategory: Category?
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var linkToSavings = false
    @State private var selectedSavingsAccount: SavingsAccount?
    @State private var tagsText = ""

    // Splits (multi-catégories)
    @State private var useSplits = false
    @State private var splitLines: [(categoryName: String, amount: String)] = []

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    private var currencySymbol: String {
        currencyService.symbol(for: currency)
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

                Section("Compte d'épargne") {
                    Toggle("Affecter cette transaction à un compte", isOn: $linkToSavings)
                    if linkToSavings {
                        if savingsAccounts.isEmpty {
                            Text("Aucun compte d'épargne disponible")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Compte", selection: $selectedSavingsAccount) {
                                Text("Sélectionner un compte").tag(Optional<SavingsAccount>.none)
                                ForEach(savingsAccounts) { account in
                                    Text("\(account.icon) \(account.name) (\(account.currency))")
                                        .tag(Optional(account))
                                }
                            }
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
                    
                    Section("Répartition (multi-catégories)") {
                        Toggle("Utiliser une répartition", isOn: $useSplits)
                        if useSplits {
                            if splitLines.isEmpty {
                                Text("Aucune ligne de répartition")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(splitLines.enumerated()), id: \.0) { index, line in
                                    HStack {
                                        Menu(line.categoryName.isEmpty ? "Catégorie" : line.categoryName) {
                                            ForEach(categories) { cat in
                                                Button(action: { splitLines[index].categoryName = cat.name }) {
                                                    Text("\(cat.icon) \(cat.name)")
                                                }
                                            }
                                        }
                                        .buttonStyle(.bordered)

                                        TextField("Montant", text: Binding(
                                            get: { splitLines[index].amount },
                                            set: { splitLines[index].amount = $0 }
                                        ))
                                        .keyboardType(.decimalPad)

                                        Button(role: .destructive) {
                                            splitLines.remove(at: index)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                    }
                                }
                            }
                            HStack {
                                Button {
                                    splitLines.append((categoryName: "", amount: ""))
                                } label: {
                                    Label("Ajouter une catégorie", systemImage: "plus.circle")
                                }
                                Spacer()
                                Menu("Actions") {
                                    Button("Suggérer") { suggestSplits() }
                                    Button("Normaliser") { normalizeSplits() }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Section("Budget") {
                        Toggle("Exclure cette dépense du budget", isOn: $excludeFromBudget)
                    }
                }

                Section("Note (optionnel)") {
                    TextField("Note", text: $note)
                    TextField("Tags (ex: voyage,pro,urgent)", text: $tagsText)
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
                selectedSavingsAccount = savingsAccounts.first
                excludeFromBudget = false
            }
        }
    }

    private func normalizeSplits() {
        guard let total = NumberParsing.parseDouble(amount), total != 0 else { return }
        // Map current UI lines to CategorySplit and normalize
        let rawSplits: [CategorySplit] = splitLines.compactMap { line in
            guard !line.categoryName.isEmpty, let amt = NumberParsing.parseDouble(line.amount) else { return nil }
            return CategorySplit(categoryName: line.categoryName, amount: amt)
        }
        let normalized = SplitAllocator.normalize(splits: rawSplits, to: total)
        // Reflect back into UI
        splitLines = normalized.map { (categoryName: $0.categoryName, amount: String(format: "%.2f", $0.amount)) }
    }

    private func suggestSplits() {
        // If we have a title, try a split suggestion from the classifier
        if let split = classifier.predictSplitCategories(for: title), !split.isEmpty {
            splitLines = split.map { (key: String, value: Double) in
                (categoryName: key, amount: String(format: "%.2f", value * (NumberParsing.parseDouble(amount) ?? 0)))
            }
            normalizeSplits()
            return
        }
        // Otherwise, seed with top-3 categories
        let top = classifier.suggestTop(for: title, categories: categories, limit: 3)
        guard !top.isEmpty else { return }
        let total = NumberParsing.parseDouble(amount) ?? 0
        let equal = total / Double(top.count == 0 ? 1 : top.count)
        splitLines = top.map { (categoryName: $0.name, amount: String(format: "%.2f", equal)) }
        normalizeSplits()
    }

    private var isValid: Bool {
        if title.isEmpty { return false }
        guard let total = NumberParsing.parseDouble(amount) else { return false }
        if type == .expense && useSplits {
            let validLines = splitLines.compactMap { NumberParsing.parseDouble($0.amount) }
            return !validLines.isEmpty && total != 0
        }
        return true
    }

    private func save() {
        guard let amt = NumberParsing.parseDouble(amount) else { return }

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
            category: nil,
            categoryNameSnapshot: selectedCategory?.name,
            categoryIconSnapshot: selectedCategory?.icon,
            categoryColorHexSnapshot: selectedCategory?.colorHex,
            note: storedNote,
            noteCiphertext: ciphertext,
            noteHash: noteHash,
            excludedFromBudget: excludeFromBudget,
            tagsRaw: tagsText
        )

        if type == .expense && useSplits {
            let uiSplits: [CategorySplit] = splitLines.compactMap { line in
                guard !line.categoryName.isEmpty, let amt = NumberParsing.parseDouble(line.amount) else { return nil }
                return CategorySplit(categoryName: line.categoryName, amount: amt)
            }
            if !uiSplits.isEmpty {
                transaction.applySplits(uiSplits)
                // Si on utilise une répartition, on efface le snapshot mono-catégorie pour éviter les ambiguïtés
                transaction.categoryNameSnapshot = nil
                transaction.categoryIconSnapshot = nil
                transaction.categoryColorHexSnapshot = nil
            }
        }

        transactionVM.add(transaction: transaction, context: context)

        if linkToSavings, let account = selectedSavingsAccount {
            let convertedAmount = transactionVM.converted(
                amount: amt,
                from: currency,
                to: account.currency,
                rates: currencyService.rates
            )
            let signedDelta: Double
            switch type {
            case .expense:
                signedDelta = -convertedAmount
            case .income:
                signedDelta = convertedAmount
            case .loan:
                signedDelta = 0
            }
            if signedDelta != 0 {
                let newBalance = account.balance + signedDelta
                let impact = signedDelta > 0 ? "+" : "-"
                let note = "\(impact)\(abs(convertedAmount).formatted(.number.precision(.fractionLength(2)))) \(account.currency) via \(title)"
                savingsVM.updateBalance(account: account, newBalance: newBalance, note: note, context: context)
            }
        }

        if type == .expense, let selectedCategory {
            classifier.addTrainingSample(title: title, categoryName: selectedCategory.name)
        }

        if isRecurring {
            transactionVM.addRecurringTemplate(from: transaction, frequency: recurrenceFrequency, context: context)
        }

        dismiss()
    }
}

