import SwiftUI
import SwiftData
import Charts

struct SavingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SavingsViewModel.self) private var savingsVM
    @Query private var accounts: [SavingsAccount]
    @Query private var goals: [SavingsGoal]
    @State private var selectedCurrency = "EUR"
    @State private var showAddAccount = false
    @State private var showAddGoal = false

    private var symbol: String { selectedCurrency == "EUR" ? "€" : "฿" }
    private var totalWorth: Double { savingsVM.totalWorth(in: selectedCurrency, rates: currencyService.rates) }

    var body: some View {
        List {
            Section {
                Picker("", selection: $selectedCurrency) {
                    Text("EUR €").tag("EUR")
                    Text("THB ฿").tag("THB")
                }
                .pickerStyle(.segmented)
            }

            Section("Net worth") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total épargne")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(symbol)\(String(format: "%.2f", totalWorth))")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(accounts) { account in
                    NavigationLink(destination: SavingsAccountDetailView(account: account)) {
                        HStack {
                            Text(account.icon).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name).font(.body)
                                Text(account.currency)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(account.currency == "EUR" ? "€" : "฿")\(String(format: "%.2f", account.balance))")
                                .bold()
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { savingsVM.deleteAccount(account: accounts[$0], context: context) }
                }

                Button { showAddAccount = true } label: {
                    Label("Ajouter un compte", systemImage: "plus.circle")
                }
            } header: {
                Text("Comptes épargne")
            }

            Section("Objectifs") {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(goal.icon)
                            Text(goal.name).font(.body.bold())
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: goal.progress)
                            .tint(goal.progress >= 1 ? .green : .blue)
                        HStack {
                            Text("\(goal.currency == "EUR" ? "€" : "฿")\(String(format: "%.0f", goal.current))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(goal.currency == "EUR" ? "€" : "฿")\(String(format: "%.0f", goal.target))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let deadline = goal.deadline {
                            Text("Échéance : \(deadline.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    indexSet.forEach { savingsVM.deleteGoal(goal: goals[$0], context: context) }
                }

                Button { showAddGoal = true } label: {
                    Label("Ajouter un objectif", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Savings")
        .onAppear {
            savingsVM.accounts = accounts
            savingsVM.goals = goals
        }
        .sheet(isPresented: $showAddAccount) {
            AddSavingsAccountView()
        }
        .sheet(isPresented: $showAddGoal) {
            AddSavingsGoalView()
        }
    }
}
