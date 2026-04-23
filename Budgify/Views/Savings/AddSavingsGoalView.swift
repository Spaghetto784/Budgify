import SwiftUI

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM

    @State private var name = ""
    @State private var target = ""
    @State private var current = ""
    @State private var currency = "EUR"
    @State private var icon = "🎯"
    @State private var hasDeadline = false
    @State private var deadline = Date.now

    private let icons = ["🎯", "🏠", "✈️", "🎓", "💍", "🚗", "💻", "🎮"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de l'objectif", text: $name)
                    TextField("Montant cible", text: $target)
                        .keyboardType(.decimalPad)
                    TextField("Déjà épargné", text: $current)
                        .keyboardType(.decimalPad)
                    Picker("Devise", selection: $currency) {
                        Text("EUR €").tag("EUR")
                        Text("THB ฿").tag("THB")
                    }
                }
                Section {
                    Toggle("Échéance", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Date", selection: $deadline, displayedComponents: .date)
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
            .navigationTitle("Nouvel objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Créer") { save() }
                        .disabled(name.isEmpty || Double(target) == nil)
                }
            }
        }
    }

    private func save() {
        guard let tgt = Double(target) else { return }
        let cur = Double(current) ?? 0
        let goal = SavingsGoal(name: name, target: tgt, current: cur, currency: currency, deadline: hasDeadline ? deadline : nil, icon: icon)
        savingsVM.addGoal(goal: goal, context: context)
        dismiss()
    }
}
