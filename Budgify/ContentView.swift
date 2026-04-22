import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(CurrencyService.self) private var currencyService
    @Query private var expenses: [Expense]

    var body: some View {
        NavigationStack {
            List(expenses) { expense in
                Text(expense.title)
            }
            .navigationTitle("Budgify")
        }
    }
}
