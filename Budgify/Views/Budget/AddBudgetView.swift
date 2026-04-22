import SwiftUI
import SwiftData
struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(BudgetViewModel.self) private var budgetVM

    @State private var limit = ""
    @State private var currency = "EUR"
    @State private var month = Date.now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Mois", selection: $month, displayedComponents: [.date])
                TextField("Limite", text: $limit)
                    .keyboardType(.decimalPad)
                Picker("Devise", selection: $currency) {
                    Text("EUR €").tag("EUR")
                    Text("THB ฿").tag("THB")
                }
            }
            .navigationTitle("Nouveau budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") { save() }
                        .disabled(Double(limit) == nil)
                }
            }
        }
    }

    private func save() {
        guard let lmt = Double(limit) else { return }
        budgetVM.add(budget: Budget(month: month, limit: lmt, currency: currency), context: context)
        dismiss()
    }
}
