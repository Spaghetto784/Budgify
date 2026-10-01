import SwiftUI
import SwiftData
import Charts

struct SavingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(CurrencyService.self) private var currencyService
    @Environment(SavingsViewModel.self) private var savingsVM
    @Environment(SettingsViewModel.self) private var settingsVM
    @Query private var accounts: [SavingsAccount]
    @Query private var goals: [SavingsGoal]
    @State private var selectedCurrency = "EUR"
    @State private var showAddAccount = false
    @State private var showAddGoal = false
    @State private var showTransfer = false
    @State private var animateValues = false
    @Namespace private var animation

    private var symbol: String { currencyService.symbol(for: selectedCurrency) }
    private var totalWorth: Double { savingsVM.totalWorth(in: selectedCurrency, rates: currencyService.rates) }

    private var displayCurrencies: [String] {
        settingsVM.selectedCurrencies(available: currencyService.availableCurrencies)
    }

    var body: some View {
        List {
            Section {
                Picker("Devise", selection: $selectedCurrency) {
                    ForEach(displayCurrencies, id: \.self) { c in
                        Text(currencyService.displayLabel(for: c)).tag(c)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Net worth") {
                VStack(spacing: 16) {
                    // Large total display
                    VStack(spacing: 4) {
                        Text("Total épargne")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(symbol)\(String(format: "%.2f", totalWorth))")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.1), radius: 10, y: 5)
                    }
                    
                    // Quick stats
                    if !accounts.isEmpty {
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("\(accounts.count)")
                                    .font(.title2.bold())
                                    .contentTransition(.numericText())
                                Text("Comptes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
                            
                            VStack(spacing: 4) {
                                Text("\(goals.count)")
                                    .font(.title2.bold())
                                    .contentTransition(.numericText())
                                Text("Objectifs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal)
                .scaleEffect(animateValues ? 1 : 0.9)
                .opacity(animateValues ? 1 : 0)
            }

            Section {
                ForEach(accounts) { account in
                    NavigationLink(destination: SavingsAccountDetailView(account: account)) {
                        HStack {
                            Text(account.icon).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name).font(.body)
                                Text("\(account.accountType.label) • \(account.currency)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(currencyService.symbol(for: account.currency))\(String(format: "%.2f", account.balance))")
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
                Button { showTransfer = true } label: {
                    Label("Virement entre comptes", systemImage: "arrow.left.arrow.right.circle")
                }
                .disabled(accounts.count < 2)
            } header: {
                Text("Comptes")
            }

            Section("Objectifs") {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(goal.icon)
                                .font(.title)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.name)
                                    .font(.headline)
                                if let deadline = goal.deadline {
                                    Text("Échéance : \(deadline.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(goal.progress * 100))%")
                                    .font(.title3.bold())
                                    .foregroundStyle(goal.progress >= 1 ? .green : .blue)
                                    .contentTransition(.numericText())
                                if goal.progress >= 1 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        
                        // Progress bar with animation
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.gray.opacity(0.2))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: goal.progress >= 1 ? [.green, .green.opacity(0.7)] : [.blue, .blue.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * min(animateValues ? goal.progress : 0, 1), height: 12)
                                    .animation(.spring(duration: 1.0, bounce: 0.3), value: animateValues)
                            }
                        }
                        .frame(height: 12)
                        
                        HStack {
                            Text("\(currencyService.symbol(for: goal.currency))\(String(format: "%.0f", goal.current))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(currencyService.symbol(for: goal.currency))\(String(format: "%.0f", goal.target))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                        
                        if let weekly = savingsVM.recommendedWeeklyContribution(for: goal) {
                            HStack {
                                Image(systemName: weekly > 0 ? "lightbulb.fill" : "star.fill")
                                    .foregroundStyle(weekly > 0 ? .blue : .green)
                                    .imageScale(.small)
                                Text(weekly > 0 ? "Recommandé : \(currencyService.symbol(for: goal.currency))\(String(format: "%.2f", weekly))/semaine" : "Objectif atteint ! 🎉")
                                    .font(.caption)
                                    .foregroundStyle(weekly > 0 ? .blue : .green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill((weekly > 0 ? Color.blue : .green).opacity(0.1))
                            }
                        }
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    indexSet.forEach { savingsVM.deleteGoal(goal: goals[$0], context: context) }
                }
                Button {
                    showAddGoal = true
                } label: {
                    Label("Ajouter un objectif", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Savings")
        .onAppear {
            savingsVM.accounts = accounts
            savingsVM.goals = goals
            selectedCurrency = displayCurrencies.first ?? "EUR"
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.2)) {
                animateValues = true
            }
        }
        .onChange(of: accounts.count) { _, _ in
            animateValues = false
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.1)) {
                animateValues = true
            }
        }
        .onChange(of: goals.count) { _, _ in
            animateValues = false
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.1)) {
                animateValues = true
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddSavingsAccountView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddGoal) {
            AddSavingsGoalView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showTransfer) {
            TransferFundsView()
                .presentationDetents([.medium])
        }
    }
}
