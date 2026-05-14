import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyService.self) private var currencyService
    @Environment(TransactionViewModel.self) private var transactionVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(SecurityService.self) private var securityService
    @Query private var categories: [Category]

    let transaction: Transaction
    @State private var selectedCurrency: String
    @State private var showEdit = false
    @State private var editTitle = ""
    @State private var editAmount = ""
    @State private var editDate = Date.now
    @State private var editType: TransactionType = .expense
    @State private var editCurrency = "EUR"
    @State private var editCategory: Category?
    @State private var editNote = ""
    @State private var editExcludeFromBudget = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _selectedCurrency = State(initialValue: transaction.currency)
    }

    private var convertedAmount: Double {
        currencyService.convert(amount: transaction.amount, from: transaction.currency, to: selectedCurrency)
    }

    private var symbol: String { currencyService.symbol(for: selectedCurrency) }

    private var displayCurrencies: [String] {
        let selected = settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
        if selected.contains(transaction.currency) {
            return selected
        }
        return selected + [transaction.currency]
    }

    private var displayNote: String {
        if let ciphertext = transaction.noteCiphertext,
           let decrypted = securityService.decrypt(ciphertext) {
            return decrypted
        }
        return transaction.note
    }

    private var noteIntegrityValid: Bool? {
        guard let expectedHash = transaction.noteHash, !displayNote.isEmpty else { return nil }
        return securityService.hash(displayNote) == expectedHash
    }

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

    private var categoryLabel: String {
        if let name = transaction.resolvedCategoryName {
            return "\(transaction.resolvedCategoryIcon ?? "📌") \(name)"
        }
        return "Aucune"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    if let icon = transaction.resolvedCategoryIcon {
                        Text(icon).font(.largeTitle)
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
                Picker("Devise", selection: $selectedCurrency) {
                    ForEach(displayCurrencies, id: \.self) { code in
                        Text(currencyService.displayLabel(for: code)).tag(code)
                    }
                }
                .pickerStyle(.menu)

                Text("\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.title.bold())
                    .foregroundStyle(typeColor)
            }

            Section("Date") {
                Text(transaction.date.formatted(date: .long, time: .omitted))
            }

            if !displayNote.isEmpty {
                Section("Note") {
                    Text(displayNote)
                    if transaction.noteCiphertext != nil {
                        Label("Note chiffrée (AES-256)", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let integrity = noteIntegrityValid {
                        Label(integrity ? "Intégrité hash validée" : "Alerte: hash invalide", systemImage: integrity ? "checkmark.seal" : "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(integrity ? .green : .red)
                    }
                }
            }

            if let name = transaction.resolvedCategoryName {
                Section("Catégorie") {
                    HStack {
                        Text(transaction.resolvedCategoryIcon ?? "📌")
                        Text(name)
                        Spacer()
                        if let colorHex = transaction.resolvedCategoryColorHex {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }

            Section("Budget") {
                HStack {
                    Text("Compté dans le budget")
                    Spacer()
                    Image(systemName: transaction.excludedFromBudget ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(transaction.excludedFromBudget ? .orange : .green)
                }
                .font(.subheadline)
            }

            Section {
                Button {
                    prepareEdit()
                    showEdit = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Modifier")
                        Spacer()
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
        .sheet(isPresented: $showEdit) {
            editSheet
        }
    }

    private var editSheet: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Titre", text: $editTitle)
                    TextField("Montant", text: $editAmount)
                        .keyboardType(.decimalPad)
                    Picker("Type", selection: $editType) {
                        Text("Dépense").tag(TransactionType.expense)
                        Text("Revenu").tag(TransactionType.income)
                        Text("Prêt").tag(TransactionType.loan)
                    }
                    Picker("Devise", selection: $editCurrency) {
                        ForEach(displayCurrencies, id: \.self) { code in
                            Text(currencyService.displayLabel(for: code)).tag(code)
                        }
                    }
                    DatePicker("Date", selection: $editDate, displayedComponents: [.date])
                }

                if editType == .expense {
                    Section("Catégorie") {
                        Picker("Catégorie", selection: $editCategory) {
                            Text("Aucune").tag(Optional<Category>.none)
                            ForEach(categories) { category in
                                Text("\(category.icon) \(category.name)")
                                    .tag(Optional(category))
                            }
                        }
                    }
                }

                Section("Budget") {
                    Toggle("Exclure cette transaction du budget", isOn: $editExcludeFromBudget)
                }

                Section("Note") {
                    TextField("Note", text: $editNote, axis: .vertical)
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { showEdit = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        saveEdit()
                    }
                    .disabled(editTitle.isEmpty || NumberParsing.parseDouble(editAmount) == nil)
                }
            }
        }
    }

    private func prepareEdit() {
        editTitle = transaction.title
        editAmount = String(format: "%.2f", transaction.amount)
        editDate = transaction.date
        editType = transaction.type
        editCurrency = transaction.currency
        editExcludeFromBudget = transaction.excludedFromBudget
        editNote = displayNote
        if let categoryName = transaction.resolvedCategoryName {
            editCategory = categories.first(where: { $0.name == categoryName })
        } else {
            editCategory = nil
        }
    }

    private func saveEdit() {
        guard let parsedAmount = NumberParsing.parseDouble(editAmount) else { return }

        transaction.title = editTitle
        transaction.amount = parsedAmount
        transaction.date = editDate
        transaction.type = editType
        transaction.currency = editCurrency
        transaction.excludedFromBudget = editExcludeFromBudget

        if editType == .expense {
            transaction.categoryNameSnapshot = editCategory?.name
            transaction.categoryIconSnapshot = editCategory?.icon
            transaction.categoryColorHexSnapshot = editCategory?.colorHex
        } else {
            transaction.categoryNameSnapshot = nil
            transaction.categoryIconSnapshot = nil
            transaction.categoryColorHexSnapshot = nil
        }

        let shouldEncrypt = settingsVM.settings?.dataEncryptionEnabled == true
        if editNote.isEmpty {
            transaction.note = ""
            transaction.noteCiphertext = nil
            transaction.noteHash = nil
        } else if shouldEncrypt, let ciphertext = securityService.encrypt(editNote) {
            transaction.note = ""
            transaction.noteCiphertext = ciphertext
            transaction.noteHash = securityService.hash(editNote)
        } else {
            transaction.note = editNote
            transaction.noteCiphertext = nil
            transaction.noteHash = securityService.hash(editNote)
        }

        try? context.save()
        showEdit = false
    }
}
