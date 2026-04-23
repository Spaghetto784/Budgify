import SwiftUI

struct AddSavingsAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM

    @State private var name = ""
    @State private var balance = ""
    @State private var currency = "EUR"
    @State private var icon = "🏦"

    private let icons = ["🏦", "💰", "🐖", "📈", "🏠", "✈️", "🎓", "💎"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du compte", text: $name)
                    TextField("Solde initial", text: $balance)
                        .keyboardType(.decimalPad)
                    Picker("Devise", selection: $currency) {
                        Text("EUR €").tag("EUR")
                        Text("THB ฿").tag("THB")
                    }
                }
                Section("Icône") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(icons, id: \.self) { i in
                            Text(i)
                                .font(.title2)
                                .padding(6)
                                .background(icon == i ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { icon = i }
                        }
                    }
                }
            }
            .navigationTitle("Nouveau compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Créer") { save() }
                        .disabled(name.isEmpty || Double(balance) == nil)
                }
            }
        }
    }

    private func save() {
        guard let bal = Double(balance) else { return }
        savingsVM.addAccount(account: SavingsAccount(name: name, balance: bal, currency: currency, icon: icon), context: context)
        dismiss()
    }
}
