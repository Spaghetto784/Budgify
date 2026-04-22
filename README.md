# Budgify

Personal budget tracker for iOS built with SwiftUI, SwiftData & Swift Charts.

## Features

- Track expenses by category
- Set monthly budgets with progress tracking
- Visualize spending with native charts (Swift Charts)
- Multi-currency support (EUR & THB)
- Real-time exchange rates via ExchangeRate API

## Tech Stack

- Swift 5.9+
- SwiftUI
- SwiftData
- Swift Charts
- iOS 17+

## APIs & Services

- [ExchangeRate API](https://exchangerate-api.com) — live EUR/THB conversion

## Roadmap

- [ ] iOS Widgets (WidgetKit) — budget remaining on home screen
- [ ] Push notifications — low balance alerts, end of month reminders
- [ ] Search & filters in expense list
- [ ] Export to CSV / PDF
- [ ] iCloud sync (CloudKit)
- [ ] Apple Watch app
- [ ] Siri Shortcuts

## Getting Started

1. Clone the repo
2. Open `Budgify.xcodeproj` in Xcode 15+
3. Add your ExchangeRate API key in `Services/CurrencyService.swift`
4. Run on device or simulator (iOS 17+)

## Structure

```
Budgify/
├── Models/
│   ├── Expense.swift
│   ├── Category.swift
│   └── Budget.swift
├── Services/
│   └── CurrencyService.swift
├── ViewModels/
│   ├── ExpenseViewModel.swift
│   ├── BudgetViewModel.swift
│   └── CategoryViewModel.swift
├── Views/
│   ├── Expenses/
│   ├── Budget/
│   ├── Stats/
│   └── Categories/
└── Extensions/
    └── Color+Hex.swift
```

## License

MIT
