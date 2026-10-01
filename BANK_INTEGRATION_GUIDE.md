# 🏦 Bank Integration Implementation Guide

## Overview

This guide explains how to implement automatic transaction detection from bank notifications (Revolut, N26, etc.). Due to iOS limitations, there are multiple approaches with different trade-offs.

---

## 🚫 iOS Limitations

**Important**: iOS does **NOT** allow apps to:
- Access notifications from other apps
- Intercept system notifications
- Read notification content programmatically

This is by design for privacy and security.

---

## ✅ Possible Implementation Approaches

### Approach 1: Manual Copy-Paste (Implemented ✅)

**How it works:**
1. User receives bank notification
2. User long-presses notification → Copy
3. User opens Budgify
4. App provides "Import from Notification" button
5. User pastes text
6. App parses and creates transaction

**Pros:**
- ✅ Simple to implement
- ✅ Works with any bank
- ✅ No API needed
- ✅ Already implemented in `BankNotificationService.swift`

**Cons:**
- ❌ Requires manual action
- ❌ Not fully automatic

**Implementation:**
```swift
// Already available in BankNotificationService.swift
let service = BankNotificationService()
let detected = service.parseNotificationContent(pastedText)
```

**UI Integration:**
Add button to TransactionListView:
```swift
Button("Import from Notification") {
    showImportSheet = true
}
.sheet(isPresented: $showImportSheet) {
    ImportFromNotificationView()
}
```

---

### Approach 2: iOS Shortcuts Automation (Recommended for Power Users)

**How it works:**
1. Create iOS Shortcut triggered by notification
2. Shortcut extracts text and sends to Budgify
3. Uses URL scheme or Shortcuts actions

**Pros:**
- ✅ Automatic (once set up)
- ✅ Works in background
- ✅ User has control

**Cons:**
- ❌ Requires user setup
- ❌ iOS Shortcuts learning curve
- ❌ Bank app must be in trigger list

**Implementation Steps:**

1. **Add URL Scheme to Info.plist:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.budgify</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>budgify</string>
        </array>
    </dict>
</array>
```

2. **Handle URL in App:**
```swift
// In BudgifyApp.swift
.onOpenURL { url in
    handleIncomingURL(url)
}

func handleIncomingURL(_ url: URL) {
    // budgify://add-transaction?text=You%20spent%20€45.50%20at%20Starbucks
    guard url.scheme == "budgify",
          url.host == "add-transaction",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let text = components.queryItems?.first(where: { $0.name == "text" })?.value else {
        return
    }
    
    let service = BankNotificationService()
    if let detected = service.parseNotificationContent(text) {
        // Show quick-add sheet
        showQuickAddSheet(with: detected)
    }
}
```

3. **User Creates Shortcut:**
- Open Shortcuts app
- Create "New Automation"
- Trigger: "When I receive a notification"
- Select: Revolut (or bank app)
- Action: "Open URL"
- URL: `budgify://add-transaction?text=[Notification Content]`

---

### Approach 3: Bank API Integration (Best for Production)

**How it works:**
1. Register as developer with bank
2. Get API credentials
3. Implement OAuth flow
4. Fetch transactions directly from API

**Pros:**
- ✅ Fully automatic
- ✅ No notification parsing needed
- ✅ More reliable data
- ✅ Can fetch historical data

**Cons:**
- ❌ Requires bank partnership
- ❌ Complex OAuth implementation
- ❌ Different APIs for each bank
- ❌ May have fees

**Supported Banks with APIs:**
- **Revolut Business API**: https://developer.revolut.com
- **N26 API**: https://docs.n26.com
- **Open Banking (EU)**: PSD2 compliant APIs
- **Plaid (US/EU)**: Aggregator API

**Implementation Skeleton:**

```swift
import Foundation

class BankAPIService {
    private let clientID = "your_client_id"
    private let clientSecret = "your_client_secret"
    private var accessToken: String?
    
    // Step 1: OAuth Authentication
    func authenticate() async throws {
        // Implement OAuth 2.0 flow
        // 1. Get authorization code
        // 2. Exchange for access token
        // 3. Store securely in Keychain
    }
    
    // Step 2: Fetch Transactions
    func fetchRecentTransactions() async throws -> [BankTransaction] {
        guard let token = accessToken else {
            throw BankAPIError.notAuthenticated
        }
        
        let url = URL(string: "https://api.revolut.com/transactions")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let transactions = try JSONDecoder().decode([BankTransaction].self, from: data)
        
        return transactions
    }
    
    // Step 3: Convert to App Format
    func convertToTransaction(_ bankTx: BankTransaction) -> Transaction {
        Transaction(
            title: bankTx.description,
            amount: abs(bankTx.amount),
            date: bankTx.date,
            currency: bankTx.currency,
            type: bankTx.amount < 0 ? .expense : .income,
            category: nil,
            categoryNameSnapshot: nil,
            categoryIconSnapshot: nil,
            categoryColorHexSnapshot: nil,
            note: "Imported from \(bankTx.source)",
            noteCiphertext: nil,
            noteHash: nil,
            excludedFromBudget: false,
            tagsRaw: "imported,\(bankTx.source.lowercased())"
        )
    }
}

struct BankTransaction: Codable {
    let id: String
    let amount: Double
    let currency: String
    let description: String
    let date: Date
    let source: String
}

enum BankAPIError: Error {
    case notAuthenticated
    case networkError
    case invalidResponse
}
```

**OAuth Setup UI:**
```swift
struct BankConnectionView: View {
    @State private var apiService = BankAPIService()
    @State private var isAuthenticating = false
    @State private var isConnected = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Connect Your Bank")
                .font(.title.bold())
            
            Text("Securely connect to Revolut for automatic transaction import")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                
                Button("Sync Transactions") {
                    Task {
                        await syncTransactions()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    Task {
                        isAuthenticating = true
                        try? await apiService.authenticate()
                        isConnected = true
                        isAuthenticating = false
                    }
                } label: {
                    if isAuthenticating {
                        ProgressView()
                    } else {
                        Text("Connect with Revolut")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private func syncTransactions() async {
        do {
            let bankTransactions = try await apiService.fetchRecentTransactions()
            // Convert and save to SwiftData
            for bankTx in bankTransactions {
                let transaction = apiService.convertToTransaction(bankTx)
                // Save to context
            }
        } catch {
            print("Sync error: \(error)")
        }
    }
}
```

---

### Approach 4: Open Banking (PSD2 - European Union)

**How it works:**
1. Use Open Banking aggregator
2. Access multiple banks with single API
3. User authorizes access through bank's official flow

**Recommended Providers:**
- **TrueLayer**: https://truelayer.com
- **Plaid**: https://plaid.com/en-eu/
- **Tink**: https://tink.com

**Pros:**
- ✅ Multi-bank support
- ✅ Regulated and secure
- ✅ Standard API across banks
- ✅ Historical data access

**Cons:**
- ❌ Subscription costs
- ❌ Complex integration
- ❌ Regional limitations

---

## 🎯 Recommended Implementation Path

### Phase 1: Manual Import (Current) ✅
**Status**: Implemented in `BankNotificationService.swift`
- Copy-paste notification text
- Parse and suggest transaction
- One-tap to add

### Phase 2: Shortcuts Integration (Next)
**Timeline**: 1-2 days
- Add URL scheme handling
- Create example Shortcuts
- User documentation

### Phase 3: Bank API (Future)
**Timeline**: 2-4 weeks per bank
- Choose target bank(s)
- Register for API access
- Implement OAuth flow
- Add sync functionality

### Phase 4: Open Banking (Production)
**Timeline**: 4-8 weeks
- Choose provider (TrueLayer/Plaid)
- Integrate SDK
- Handle multiple banks
- Production testing

---

## 🔐 Security Considerations

### 1. Data Protection
```swift
// Store API tokens securely
import Security

class KeychainService {
    func save(token: String, for account: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func load(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

### 2. Network Security
```swift
// Use certificate pinning for bank APIs
class SecureNetworkManager {
    func pinnedSession() -> URLSession {
        let delegate = PinningDelegate()
        return URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
    }
}

class PinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Implement certificate pinning
        // Verify server certificate matches expected
    }
}
```

### 3. User Privacy
- Clear consent flow
- Transparent data usage
- Easy revocation
- Local processing where possible

---

## 📱 User Experience Flow

### Current Implementation (Manual)
```
Bank Notification
     ↓
User long-press → Copy
     ↓
Open Budgify
     ↓
Tap "Import from Notification"
     ↓
Paste text
     ↓
Review parsed transaction
     ↓
Confirm → Added
```

### With Shortcuts
```
Bank Notification arrives
     ↓
Shortcut triggers automatically
     ↓
Opens Budgify with data
     ↓
Quick-add sheet appears
     ↓
One-tap confirm → Added
```

### With API
```
Bank transaction occurs
     ↓
API sync (background or manual)
     ↓
New transaction detected
     ↓
Notification: "New transaction imported"
     ↓
Review in app → Confirm
```

---

## 🧪 Testing

### Test Cases for Notification Parsing

```swift
func testNotificationParsing() {
    let service = BankNotificationService()
    
    // Test 1: Basic expense
    let text1 = "You spent €45.50 at Starbucks"
    let result1 = service.parseNotificationContent(text1)
    assert(result1?.title == "Starbucks")
    assert(result1?.amount == 45.50)
    assert(result1?.type == .expense)
    
    // Test 2: Income
    let text2 = "Received €100.00 from John Smith"
    let result2 = service.parseNotificationContent(text2)
    assert(result2?.type == .income)
    
    // Test 3: Different currency
    let text3 = "Card payment -$25.99 Amazon"
    let result3 = service.parseNotificationContent(text3)
    assert(result3?.currency == "USD")
    
    // Test 4: Special characters
    let text4 = "-€15.99 • McDonald's"
    let result4 = service.parseNotificationContent(text4)
    assert(result4?.title.contains("McDonald"))
}
```

---

## 📚 Resources

### Documentation
- **Revolut API**: https://developer.revolut.com/docs/business-api
- **Open Banking**: https://www.openbanking.org.uk/
- **PSD2 Compliance**: https://ec.europa.eu/info/law/payment-services-psd-2-directive-eu-2015-2366_en

### Libraries
- **Plaid iOS SDK**: https://github.com/plaid/plaid-link-ios
- **TrueLayer SDK**: https://docs.truelayer.com/
- **KeychainAccess**: https://github.com/kishikawakatsumi/KeychainAccess

### Apple Documentation
- **URL Schemes**: https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
- **Shortcuts**: https://support.apple.com/guide/shortcuts/welcome/ios
- **Keychain**: https://developer.apple.com/documentation/security/keychain_services

---

## ✅ Quick Start Checklist

- [ ] Test current manual import feature
- [ ] Add URL scheme to Info.plist
- [ ] Implement URL handling in app
- [ ] Create example Shortcuts
- [ ] Write user documentation
- [ ] Choose bank API or aggregator
- [ ] Register for API access
- [ ] Implement OAuth flow
- [ ] Add sync functionality
- [ ] Test with real bank data
- [ ] Submit for App Store review

---

## 🆘 Support & Troubleshooting

### Common Issues

**Q: Parsing doesn't work for my bank**
A: Add new pattern to `BankNotificationService.parseNotificationContent`

**Q: Shortcut doesn't trigger**
A: Check notification settings, ensure bank app is in trigger list

**Q: API authentication fails**
A: Verify credentials, check token expiry, review OAuth flow

**Q: Can't access other app notifications**
A: This is an iOS limitation, use alternative approaches

---

**🎉 Good luck with your bank integration!**

For questions or contributions, please refer to the main project documentation.
