import SwiftUI

/// Enhanced transaction row with beautiful animations and interactions
struct EnhancedTransactionRowView: View {
    let transaction: Transaction
    let displayCurrency: String
    let rates: [String: Double]
    @Environment(CurrencyService.self) private var currencyService
    @State private var isPressed = false
    
    private var convertedAmount: Double {
        if transaction.currency == displayCurrency {
            return transaction.amount
        }
        let rate = rates["\(transaction.currency)_\(displayCurrency)"] ?? 1.0
        return transaction.amount * rate
    }
    
    private var symbol: String {
        currencyService.symbol(for: displayCurrency)
    }
    
    private var typeColor: Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .loan: return .orange
        }
    }
    
    private var typeIcon: String {
        switch transaction.type {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .loan: return "arrow.triangle.2.circlepath"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Category icon or type icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                if let icon = transaction.resolvedCategoryIcon {
                    Text(icon)
                        .font(.title2)
                } else {
                    Image(systemName: typeIcon)
                        .foregroundStyle(typeColor)
                        .font(.title3)
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(duration: 0.3), value: isPressed)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(transaction.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                
                // Category and date
                HStack(spacing: 8) {
                    if let categoryName = transaction.resolvedCategoryName {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(typeColor.opacity(0.8))
                                .frame(width: 6, height: 6)
                            Text(categoryName)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    if let categoryName = transaction.resolvedCategoryName {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    Text(transaction.date.formatted(.dateTime.day().month()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Tags if present
                if !transaction.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(transaction.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(typeColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .expense ? "-" : "+")\(symbol)\(String(format: "%.2f", convertedAmount))")
                    .font(.body.weight(.bold))
                    .foregroundStyle(typeColor)
                    .contentTransition(.numericText())
                
                // Show original currency if different
                if transaction.currency != displayCurrency {
                    Text("\(currencyService.symbol(for: transaction.currency))\(String(format: "%.2f", transaction.amount))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Recurring indicator
                if transaction.isRecurringTemplate {
                    Label("Récurrent", systemImage: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

/// Compact transaction row for widgets and summaries
struct CompactTransactionRowView: View {
    let transaction: Transaction
    let showDate: Bool
    @Environment(CurrencyService.self) private var currencyService
    
    private var symbol: String {
        currencyService.symbol(for: transaction.currency)
    }
    
    private var typeColor: Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .loan: return .orange
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = transaction.resolvedCategoryIcon {
                Text(icon)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                if showDate {
                    Text(transaction.date.formatted(.dateTime.day().month()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(transaction.type == .expense ? "-" : "+")\(symbol)\(String(format: "%.2f", transaction.amount))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(typeColor)
        }
        .padding(.vertical, 4)
    }
}

/// Animated transaction card for featured displays
struct TransactionCardView: View {
    let transaction: Transaction
    @Environment(CurrencyService.self) private var currencyService
    @State private var isVisible = false
    
    private var symbol: String {
        currencyService.symbol(for: transaction.currency)
    }
    
    private var typeColor: Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .loan: return .orange
        }
    }
    
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [typeColor.opacity(0.3), typeColor.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let icon = transaction.resolvedCategoryIcon {
                    ZStack {
                        Circle()
                            .fill(typeColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Text(icon)
                            .font(.title)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.date.formatted(.dateTime.day().month().year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if transaction.isRecurringTemplate {
                        Image(systemName: "repeat.circle.fill")
                            .foregroundStyle(typeColor)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(transaction.title)
                    .font(.title3.bold())
                
                if let categoryName = transaction.resolvedCategoryName {
                    Text(categoryName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Text(transaction.type == .expense ? "Dépense" : transaction.type == .income ? "Revenu" : "Prêt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(transaction.type == .expense ? "-" : "+")\(symbol)\(String(format: "%.2f", transaction.amount))")
                    .font(.title2.bold())
                    .foregroundStyle(typeColor)
            }
            
            if !transaction.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(transaction.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(typeColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(gradient)
                )
                .shadow(color: typeColor.opacity(0.2), radius: 10, y: 5)
        }
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview Helpers

#Preview("Enhanced Row") {
    List {
        EnhancedTransactionRowView(
            transaction: Transaction(
                title: "Starbucks Coffee",
                amount: 4.50,
                date: Date(),
                currency: "EUR",
                type: .expense,
                category: nil,
                categoryNameSnapshot: "Nourriture",
                categoryIconSnapshot: "🍔",
                categoryColorHexSnapshot: "FF6B6B",
                note: "",
                noteCiphertext: nil,
                noteHash: nil,
                excludedFromBudget: false,
                tagsRaw: "café,morning"
            ),
            displayCurrency: "EUR",
            rates: [:]
        )
    }
}

#Preview("Transaction Card") {
    ScrollView {
        VStack(spacing: 16) {
            TransactionCardView(
                transaction: Transaction(
                    title: "Monthly Salary",
                    amount: 3500,
                    date: Date(),
                    currency: "EUR",
                    type: .income,
                    category: nil,
                    categoryNameSnapshot: "Salaire",
                    categoryIconSnapshot: "💰",
                    categoryColorHexSnapshot: "27AE60",
                    note: "",
                    noteCiphertext: nil,
                    noteHash: nil,
                    excludedFromBudget: false,
                    tagsRaw: "work,monthly"
                )
            )
            
            TransactionCardView(
                transaction: Transaction(
                    title: "Grocery Shopping",
                    amount: 85.50,
                    date: Date(),
                    currency: "EUR",
                    type: .expense,
                    category: nil,
                    categoryNameSnapshot: "Nourriture",
                    categoryIconSnapshot: "🛒",
                    categoryColorHexSnapshot: "FF6B6B",
                    note: "",
                    noteCiphertext: nil,
                    noteHash: nil,
                    excludedFromBudget: false,
                    tagsRaw: "shopping"
                )
            )
        }
        .padding()
    }
}
