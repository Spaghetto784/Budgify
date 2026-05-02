import SwiftUI
import SwiftData

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SettingsViewModel.self) private var settingsVM

    @State private var name = ""
    @State private var target = ""
    @State private var current = ""
    @State private var currency = "EUR"
    @State private var icon = "🎯"
    @State private var hasDeadline = false
    @State private var deadline = Date.now

    private let icons = ["🎯", "🏠", "✈️", "🎓", "💍", "🚗", "💻", "🎮"]

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    private var weeklyNeededPreview: Double? {
        guard hasDeadline, let tgt = NumberParsing.parseDouble(target) else { return nil }
        let cur = NumberParsing.parseDouble(current) ?? 0
        let previewGoal = SavingsGoal(name: "", target: tgt, current: cur, currency: currency, deadline: deadline, icon: icon)
        return savingsVM.recommendedWeeklyContribution(for: previewGoal)
    }

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
                        ForEach(displayCurrencies, id: \.self) { c in
                            Text(currencyService.displayLabel(for: c)).tag(c)
                        }
                    }
                }
                Section {
                    Toggle("Échéance", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Date", selection: $deadline, displayedComponents: .date)
                    }
                }

                if let weeklyNeededPreview {
                    Section("Plan recommandé") {
                        HStack {
                            Text("À épargner / semaine")
                            Spacer()
                            Text("\(currencyService.symbol(for: currency))\(String(format: "%.2f", weeklyNeededPreview))")
                                .bold()
                        }
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
                        .disabled(name.isEmpty || NumberParsing.parseDouble(target) == nil)
                }
            }
            .onAppear {
                currency = displayCurrencies.first ?? "EUR"
            }
        }
    }

    private func save() {
        guard let tgt = NumberParsing.parseDouble(target) else { return }
        let cur = NumberParsing.parseDouble(current) ?? 0
        let goal = SavingsGoal(name: name, target: tgt, current: cur, currency: currency, deadline: hasDeadline ? deadline : nil, icon: icon)
        savingsVM.addGoal(goal: goal, context: context)
        dismiss()
    }
}
