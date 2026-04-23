import SwiftUI
import Charts
import SwiftData

struct SavingsAccountDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(SavingsViewModel.self) private var savingsVM
    let account: SavingsAccount
    @State private var showUpdate = false
    @State private var newBalance = ""
    @State private var note = ""

    var body: some View {
        List {
            Section("Solde actuel") {
                HStack {
                    Text(account.icon).font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text(account.name).font(.title3.bold())
                        Text(account.currency).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(account.currency == "EUR" ? "€" : "฿")\(String(format: "%.2f", account.balance))")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)

                Button("Mettre à jour le solde") { showUpdate = true }
            }

            if account.history.count > 1 {
                Section("Historique") {
                    Chart(account.history.sorted { $0.date < $1.date }, id: \.date) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Solde", entry.balance)
                        )
                        .foregroundStyle(.blue)
                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("Solde", entry.balance)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                    }
                    .frame(height: 150)
                    .padding(.vertical, 8)
                }

                Section("Entrées") {
                    ForEach(account.history.sorted { $0.date > $1.date }, id: \.date) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.body)
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(account.currency == "EUR" ? "€" : "฿")\(String(format: "%.2f", entry.balance))")
                                .bold()
                        }
                    }
                }
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUpdate) {
            NavigationStack {
                Form {
                    TextField("Nouveau solde", text: $newBalance)
                        .keyboardType(.decimalPad)
                    TextField("Note (optionnel)", text: $note)
                }
                .navigationTitle("Mettre à jour")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Annuler") { showUpdate = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Enregistrer") {
                            guard let bal = Double(newBalance) else { return }
                            savingsVM.updateBalance(account: account, newBalance: bal, note: note, context: context)
                            showUpdate = false
                        }
                        .disabled(Double(newBalance) == nil)
                    }
                }
            }
        }
    }
}
