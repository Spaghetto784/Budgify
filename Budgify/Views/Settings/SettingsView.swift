import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(CurrencyService.self) private var currencyService

    private let accentColors: [(name: String, hex: String)] = [
        ("Vert", "27AE60"),
        ("Bleu", "2980B9"),
        ("Violet", "8E44AD"),
        ("Orange", "E67E22"),
        ("Rouge", "E74C3C"),
        ("Teal", "16A085")
    ]

    private let backgroundStyles: [(name: String, value: String)] = [
        ("Système", "system"),
        ("Clair", "light"),
        ("Sombre", "dark")
    ]

    private var availableCurrencies: [String] {
        let fallback = ["EUR", "USD", "GBP", "JPY", "CHF", "CAD", "AUD", "CNY", "INR", "SGD", "THB"]
        return currencyService.availableCurrencies.isEmpty ? fallback : currencyService.availableCurrencies
    }

    private var selectedCurrencies: [String] {
        settingsVM.selectedCurrencies(available: availableCurrencies)
    }

    var body: some View {
        NavigationStack {
            if let settings = settingsVM.settings {
                Form {
                    Section("Apparence") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Couleur d'accent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                ForEach(accentColors, id: \.hex) { color in
                                    Circle()
                                        .fill(Color(hex: color.hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: settings.accentColorHex == color.hex ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            settings.accentColorHex = color.hex
                                            settingsVM.save(context: context)
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        Picker("Thème", selection: Binding(
                            get: { settings.backgroundStyle },
                            set: { settings.backgroundStyle = $0; settingsVM.save(context: context) }
                        )) {
                            ForEach(backgroundStyles, id: \.value) { style in
                                Text(style.name).tag(style.value)
                            }
                        }
                    }

                    Section("Devises") {
                        Text("Choisis les devises disponibles dans l'app (minimum 1).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(availableCurrencies, id: \.self) { code in
                            Button {
                                settingsVM.toggleCurrency(code, available: availableCurrencies, context: context)
                            } label: {
                                HStack {
                                    Text(currencyService.displayLabel(for: code))
                                    Spacer()
                                    if selectedCurrencies.contains(code) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section("Sécurité") {
                        Toggle("Face ID / Touch ID", isOn: Binding(
                            get: { settings.faceIDEnabled },
                            set: { settings.faceIDEnabled = $0; settingsVM.save(context: context) }
                        ))

                        Toggle("Chiffrement des notes", isOn: Binding(
                            get: { settings.dataEncryptionEnabled },
                            set: { settings.dataEncryptionEnabled = $0; settingsVM.save(context: context) }
                        ))

                        if settings.faceIDEnabled {
                            Section("Protection par onglet") {
                                ForEach(["Transactions", "Budget", "Stats", "Savings", "Catégories"], id: \.self) { tab in
                                    Toggle(tab, isOn: Binding(
                                        get: { settings.protectedTabs.contains(tab) },
                                        set: { enabled in
                                            if enabled {
                                                if !settings.protectedTabs.contains(tab) {
                                                    settings.protectedTabs.append(tab)
                                                }
                                            } else {
                                                settings.protectedTabs.removeAll { $0 == tab }
                                            }
                                            settingsVM.save(context: context)
                                        }
                                    ))
                                }
                            }
                        }
                    }

                    Section("Alertes budget") {
                        Toggle("Notifications intelligentes", isOn: Binding(
                            get: { settings.budgetAlertsEnabled },
                            set: { enabled in
                                settingsVM.setBudgetAlertsEnabled(enabled, context: context)
                            }
                        ))
                        Text("Alerte à 80%, à 100%, et projection de dépassement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("App") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Réglages")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer") { dismiss() }
                    }
                }
            } else {
                ProgressView()
            }
        }
    }
}
