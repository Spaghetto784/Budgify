import SwiftUI
import SwiftData

private enum SavingsAccountPreset: String, CaseIterable, Identifiable {
    case custom
    case ccp
    case livretA
    case lep
    case pel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .custom: return "Personnalisé"
        case .ccp: return "CCP"
        case .livretA: return "Livret A"
        case .lep: return "LEP"
        case .pel: return "PEL"
        }
    }
}

struct AddSavingsAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SettingsViewModel.self) private var settingsVM

    @State private var name = ""
    @State private var balance = ""
    @State private var currency = "EUR"
    @State private var icon = "🏦"
    @State private var accountType: AccountType = .bank
    @State private var annualYieldRate = ""
    @State private var preset: SavingsAccountPreset = .custom

    private let icons = ["🏦", "💰", "🐖", "📈", "🏠", "✈️", "🎓", "💎"]

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Preset", selection: $preset) {
                        ForEach(SavingsAccountPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .onChange(of: preset) { _, newValue in
                        applyPreset(newValue)
                    }

                    TextField("Nom du compte", text: $name)
                    TextField("Solde initial", text: $balance)
                        .keyboardType(.decimalPad)
                    TextField("Taux rendement annuel (%)", text: $annualYieldRate)
                        .keyboardType(.decimalPad)
                    Picker("Type de compte", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    Picker("Devise", selection: $currency) {
                        ForEach(displayCurrencies, id: \.self) { code in
                            Text(currencyService.displayLabel(for: code)).tag(code)
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
            .navigationTitle("Nouveau compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Créer") { save() }
                        .disabled(name.isEmpty || NumberParsing.parseDouble(balance) == nil)
                }
            }
            .onAppear {
                currency = displayCurrencies.first ?? "EUR"
            }
        }
    }

    private func save() {
        guard let bal = NumberParsing.parseDouble(balance) else { return }
        let yieldRate = NumberParsing.parseDouble(annualYieldRate) ?? 0
        savingsVM.addAccount(
            account: SavingsAccount(
                name: name,
                balance: bal,
                currency: currency,
                icon: icon,
                accountType: accountType,
                annualYieldRate: max(yieldRate, 0)
            ),
            context: context
        )
        dismiss()
    }

    private func applyPreset(_ preset: SavingsAccountPreset) {
        switch preset {
        case .custom:
            break
        case .ccp:
            name = "CCP"
            icon = "🏦"
            accountType = .bank
            annualYieldRate = "0"
        case .livretA:
            name = "Livret A"
            icon = "🐖"
            accountType = .bank
            annualYieldRate = "3"
        case .lep:
            name = "LEP"
            icon = "💰"
            accountType = .bank
            annualYieldRate = "5"
        case .pel:
            name = "PEL"
            icon = "🏠"
            accountType = .bank
            annualYieldRate = "2"
        }
    }
}
