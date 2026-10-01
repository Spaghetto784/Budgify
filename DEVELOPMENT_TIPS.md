# 💡 Development Tips & Best Practices

## Quick Reference for Enhanced Features

### 🎨 Animation Best Practices

#### When to Use Each Animation Type

**Spring Animations** - Natural, bouncy feel
```swift
.animation(.spring(duration: 0.8, bounce: 0.3), value: someValue)
```
✅ Use for: Button presses, modal presentations, progress changes
❌ Avoid for: Continuous scrolling, rapid state changes

**Smooth Transitions** - General purpose
```swift
.animation(.smooth, value: someValue)
```
✅ Use for: View transitions, filter changes, most UI updates
❌ Avoid for: Precise animations, when spring physics needed

**Content Transitions** - Number changes
```swift
.contentTransition(.numericText())
```
✅ Use for: Monetary amounts, counters, percentages
❌ Avoid for: Text that's not numeric

**Asymmetric Transitions** - Directional feel
```swift
.transition(.asymmetric(
    insertion: .move(edge: .trailing).combined(with: .opacity),
    removal: .move(edge: .leading).combined(with: .opacity)
))
```
✅ Use for: List items, navigation, carousel items
❌ Avoid for: Static content, overlays

#### Performance Tips

1. **Batch Animations**
```swift
// Good ✅
withAnimation {
    value1 = newValue1
    value2 = newValue2
    value3 = newValue3
}

// Bad ❌
withAnimation { value1 = newValue1 }
withAnimation { value2 = newValue2 }
withAnimation { value3 = newValue3 }
```

2. **Use Explicit Animation**
```swift
// Good ✅ - Only animates what you want
withAnimation(.smooth) {
    isExpanded.toggle()
}

// Avoid ⚠️ - Animates ALL changes
.animation(.smooth)
```

3. **Lazy Loading**
```swift
// For long lists
LazyVStack {
    ForEach(items) { item in
        ItemView(item: item)
    }
}
```

---

### 🛡️ Input Validation Usage

#### Quick Validation Examples

**Validate Amount**
```swift
let result = InputValidationHelper.validateAmount(
    amountText,
    allowNegative: false,
    maxValue: 1_000_000
)

switch result {
case .valid(let amount):
    // Use amount safely
    transaction.amount = amount
    
case .warning(let message, let amount):
    // Show warning but allow
    showWarning(message)
    transaction.amount = amount
    
case .invalid(let message):
    // Block and show error
    showError(message)
    return
}
```

**Validate Title**
```swift
let result = InputValidationHelper.validateTitle(titleText)
if let title = result.value {
    transaction.title = title
} else {
    showError(result.message ?? "Invalid title")
}
```

**Validate Multiple Inputs**
```swift
// Create validation function
func validateTransactionInput() -> Bool {
    // Validate title
    guard case .valid(let title) = InputValidationHelper.validateTitle(titleText) else {
        return false
    }
    
    // Validate amount
    guard case .valid(let amount) = InputValidationHelper.validateAmount(amountText) else {
        return false
    }
    
    // Validate date
    guard case .valid(let date) = InputValidationHelper.validateDate(selectedDate) else {
        return false
    }
    
    // All valid - can proceed
    self.validatedTitle = title
    self.validatedAmount = amount
    self.validatedDate = date
    return true
}
```

#### Common Validation Patterns

**Optional Fields**
```swift
var note: String {
    if noteText.isEmpty { return "" }
    
    let result = InputValidationHelper.validateTitle(noteText, maxLength: 500)
    return result.value ?? ""
}
```

**With User Feedback**
```swift
@State private var validationMessage: String?
@State private var showValidationAlert = false

func validate() {
    let result = InputValidationHelper.validateAmount(amountText)
    
    switch result {
    case .valid:
        validationMessage = nil
        proceed()
        
    case .warning(let message, let value):
        validationMessage = message
        showValidationAlert = true
        // Still allow to proceed with value
        
    case .invalid(let message):
        validationMessage = message
        showValidationAlert = true
        // Block proceeding
    }
}
```

---

### 📊 Chart Best Practices

#### Chart Type Selection

**Pie Chart** - Part of whole
```swift
Chart(data, id: \.id) { item in
    SectorMark(
        angle: .value("Value", item.value),
        innerRadius: .ratio(0.55), // Donut style
        angularInset: 2 // Spacing between sectors
    )
    .foregroundStyle(Color(hex: item.color))
}
```
✅ Use for: Category breakdowns, budget allocation
❌ Avoid for: Many categories (>8), temporal data

**Bar Chart** - Comparison
```swift
Chart(data, id: \.id) { item in
    BarMark(
        x: .value("Value", item.value),
        y: .value("Category", item.name)
    )
    .foregroundStyle(Color(hex: item.color))
}
```
✅ Use for: Category comparisons, rankings
❌ Avoid for: Temporal trends, part-to-whole

**Line Chart** - Trends over time
```swift
Chart(data, id: \.id) { item in
    LineMark(
        x: .value("Date", item.date),
        y: .value("Amount", item.amount)
    )
    .foregroundStyle(Color.blue)
}
```
✅ Use for: Time series, trends, forecasts
❌ Avoid for: Discrete categories, snapshots

#### Chart Customization

**Animations**
```swift
Chart(data, id: \.id) { item in
    SectorMark(
        angle: .value("Value", animateChart ? item.value : 0)
    )
}
.onAppear {
    withAnimation(.spring(duration: 0.8)) {
        animateChart = true
    }
}
```

**Annotations**
```swift
SectorMark(...)
    .annotation(position: .overlay) {
        if item.value > threshold {
            Text(item.icon)
                .font(.title2)
        }
    }
```

**Custom Axes**
```swift
.chartXAxis {
    AxisMarks(values: .automatic) { value in
        AxisValueLabel {
            if let date = value.as(Date.self) {
                Text(date.formatted(.dateTime.month(.abbreviated)))
            }
        }
    }
}
```

---

### 🎯 SwiftData Best Practices

#### Efficient Queries

**Use Predicates**
```swift
// Good ✅
@Query(filter: #Predicate<Transaction> { transaction in
    transaction.type == .expense && 
    !transaction.excludedFromBudget
}) private var expenses: [Transaction]

// Less efficient ❌
@Query private var allTransactions: [Transaction]
var expenses: [Transaction] {
    allTransactions.filter { $0.type == .expense && !$0.excludedFromBudget }
}
```

**Sort at Query Level**
```swift
// Good ✅
@Query(sort: \Transaction.date, order: .reverse) 
private var transactions: [Transaction]

// Less efficient ❌
@Query private var transactions: [Transaction]
var sorted: [Transaction] {
    transactions.sorted { $0.date > $1.date }
}
```

**Limit Results**
```swift
// For large datasets
@Query(
    filter: #Predicate<Transaction> { $0.type == .expense },
    sort: \Transaction.date,
    order: .reverse
)
private var recentExpenses: [Transaction]

// Then in view
var limitedExpenses: [Transaction] {
    Array(recentExpenses.prefix(100))
}
```

#### Safe Context Usage

**Batch Operations**
```swift
func addMultipleTransactions(_ transactions: [Transaction]) {
    // Good ✅ - Single save
    transactions.forEach { context.insert($0) }
    try? context.save()
    
    // Bad ❌ - Multiple saves
    transactions.forEach { 
        context.insert($0)
        try? context.save()
    }
}
```

**Background Processing**
```swift
// For heavy operations
Task.detached {
    let backgroundContext = ModelContext(modelContainer)
    
    // Do heavy work
    // ...
    
    try? backgroundContext.save()
    
    await MainActor.run {
        // Update UI
    }
}
```

---

### 🎨 Color & Design Tips

#### Semantic Colors

```swift
// Good ✅ - Adapts to light/dark mode
.foregroundStyle(.secondary)
.background(.thinMaterial)

// Avoid ❌ - Fixed colors
.foregroundStyle(.gray)
.background(Color(white: 0.9))
```

#### Gradients

```swift
// Subtle gradient for cards
LinearGradient(
    colors: [color.opacity(0.3), color.opacity(0.1)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// Vibrant gradient for highlights
LinearGradient(
    colors: [color, color.opacity(0.7)],
    startPoint: .leading,
    endPoint: .trailing
)
```

#### Shadows

```swift
// Subtle elevation
.shadow(color: .black.opacity(0.05), radius: 5, y: 2)

// More prominent
.shadow(color: color.opacity(0.2), radius: 10, y: 5)

// Avoid excessive shadows
.shadow(radius: 50) // ❌ Too much
```

---

### 🔍 Debugging Tips

#### Animation Issues

```swift
// See all animations
let _ = print(Mirror(reflecting: self).children)

// Slow down animations (in Simulator)
// Debug → Slow Animations (⌘T)

// Add animation logging
withAnimation(.spring(duration: 0.8)) {
    print("🎬 Animating value change")
    value = newValue
}
```

#### SwiftData Issues

```swift
// Enable verbose logging
UserDefaults.standard.set(true, forKey: "com.apple.CoreData.SQLDebug")

// Check model state
print("Context has changes: \(context.hasChanges)")
print("Inserted count: \(context.insertedObjects.count)")

// Validate before save
do {
    try context.save()
} catch {
    print("❌ Save error: \(error)")
    // Inspect error details
}
```

#### Layout Issues

```swift
// Visualize layout
.border(.red) // Quick border
.background(.blue.opacity(0.2)) // See bounds

// Print geometry
GeometryReader { geo in
    Color.clear
        .onAppear {
            print("Size: \(geo.size)")
        }
}
```

---

### ⚡ Performance Optimization

#### Avoid Common Pitfalls

**Heavy Computations in Body**
```swift
// Bad ❌
var body: some View {
    let sortedItems = items.sorted() // Runs every render
    List(sortedItems) { ... }
}

// Good ✅
var body: some View {
    List(sortedItems) { ... }
}

private var sortedItems: [Item] {
    items.sorted() // Cached
}
```

**Unnecessary View Updates**
```swift
// Bad ❌
@State private var allData: [Item] = []
Text("\(allData.count) items") // Redraws on any array change

// Good ✅
@State private var count: Int = 0
Text("\(count) items") // Only redraws when count changes
```

**Large Image Assets**
```swift
// Optimize images
Image("large-photo")
    .resizable()
    .scaledToFit()
    .frame(maxWidth: 300)
    .clipped()

// For remote images, cache properly
// Use AsyncImage or SDWebImage
```

#### Profiling

1. **Instruments** (⌘I in Xcode)
   - Time Profiler: CPU usage
   - Allocations: Memory usage
   - SwiftUI: View body counts

2. **View Debugging** (Debug → View Debugging → Capture View Hierarchy)
   - See view tree
   - Check for redundant views
   - Inspect layout issues

---

### 🧪 Testing Tips

#### Preview Helpers

```swift
extension Transaction {
    static var preview: Transaction {
        Transaction(
            title: "Sample Transaction",
            amount: 42.50,
            date: Date(),
            currency: "EUR",
            type: .expense,
            category: nil,
            categoryNameSnapshot: "Food",
            categoryIconSnapshot: "🍔",
            categoryColorHexSnapshot: "FF6B6B",
            note: "",
            noteCiphertext: nil,
            noteHash: nil,
            excludedFromBudget: false,
            tagsRaw: "lunch,work"
        )
    }
    
    static var previewIncome: Transaction {
        Transaction(
            title: "Salary",
            amount: 3000,
            date: Date(),
            currency: "EUR",
            type: .income,
            category: nil,
            categoryNameSnapshot: nil,
            categoryIconSnapshot: nil,
            categoryColorHexSnapshot: nil,
            note: "",
            noteCiphertext: nil,
            noteHash: nil,
            excludedFromBudget: false,
            tagsRaw: ""
        )
    }
}

// Use in previews
#Preview {
    NavigationStack {
        TransactionDetailView(transaction: .preview)
    }
}
```

#### Unit Tests

```swift
import Testing

@Suite("Input Validation Tests")
struct ValidationTests {
    
    @Test("Valid amount")
    func testValidAmount() {
        let result = InputValidationHelper.validateAmount("42.50")
        #expect(result.isValid)
        #expect(result.value == 42.50)
    }
    
    @Test("Invalid amount - empty")
    func testEmptyAmount() {
        let result = InputValidationHelper.validateAmount("")
        #expect(!result.isValid)
    }
    
    @Test("Amount with multiple decimals")
    func testMultipleDecimals() {
        let result = InputValidationHelper.validateAmount("42.5.0")
        #expect(!result.isValid)
    }
    
    @Test("Amount rounding")
    func testRounding() {
        let result = InputValidationHelper.validateAmount("42.567")
        if case .warning(_, let value) = result {
            #expect(value == 42.57)
        }
    }
}
```

---

### 📝 Code Organization

#### File Structure

```
Budgify/
├── Models/
│   ├── Transaction.swift
│   ├── Budget.swift
│   └── Category.swift
├── Views/
│   ├── Transactions/
│   │   ├── TransactionListView.swift
│   │   ├── TransactionDetailView.swift
│   │   └── AddTransactionView.swift
│   ├── Budget/
│   ├── Stats/
│   └── Savings/
├── ViewModels/
│   ├── TransactionViewModel.swift
│   └── BudgetViewModel.swift
├── Services/
│   ├── CurrencyService.swift
│   ├── BankNotificationService.swift
│   └── ValidationService.swift
├── Utilities/
│   ├── Extensions/
│   ├── Helpers/
│   └── Constants/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

#### Code Style

```swift
// MARK: - Properties

// MARK: - Computed Properties

// MARK: - Body

// MARK: - Views

// MARK: - Methods

// MARK: - Private Methods
```

---

### 🚀 Deployment Checklist

- [ ] Test on multiple device sizes
- [ ] Test in light & dark mode
- [ ] Test with Dynamic Type (large fonts)
- [ ] Test with VoiceOver
- [ ] Validate all inputs
- [ ] Handle edge cases
- [ ] Add error handling
- [ ] Optimize images
- [ ] Check for memory leaks
- [ ] Profile performance
- [ ] Write unit tests
- [ ] Update documentation
- [ ] Test offline mode
- [ ] Test with empty data
- [ ] Test with maximum data
- [ ] Increment version number
- [ ] Update changelog

---

### 🆘 Common Issues & Solutions

**Issue**: Animation stutters
**Solution**: Reduce animation complexity, use `.drawingGroup()`

**Issue**: SwiftData not updating
**Solution**: Check @Query placement, ensure context.save() is called

**Issue**: View not refreshing
**Solution**: Verify @State/@Published, check observation

**Issue**: Memory growing
**Solution**: Profile with Instruments, check for retain cycles

**Issue**: Slow scrolling
**Solution**: Use LazyVStack/LazyHStack, optimize row views

---

### 📚 Recommended Reading

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [SwiftData Guide](https://developer.apple.com/documentation/swiftdata)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)

---

**🎓 Keep Learning & Building!**

Remember: Good code is readable, maintainable, and performant. 
Always prioritize user experience and code clarity.
