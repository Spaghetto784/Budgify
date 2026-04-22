import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ExpenseViewModel.self) private var expenseVM
    @Query private var categories: [Category]

    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date.now
    @State private var currency = "EUR"
    @State private var selectedCategory: Category?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titre", text: $title)
                    TextField("Montant", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Devise", selection: $currency) {
                        Text("EUR €").tag("EUR")
                        Text("THB ฿").tag("THB")
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
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
                            .onTapGesture { selectedCategory = cat }
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle dépense")
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
        !title.isEmpty && Double(amount) != nil && selectedCategory != nil
    }

    private func save() {
        guard let amt = Double(amount), let cat = selectedCategory else { return }
        let expense = Expense(title: title, amount: amt, date: date, currency: currency, category: cat)
        expenseVM.add(expense: expense, context: context)
        dismiss()
    }
}
