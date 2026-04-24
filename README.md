# Budgify

Budgify is an iOS personal finance app built with SwiftUI + SwiftData.
It focuses on practical budgeting, multi-currency tracking, local intelligence, and strong on-device privacy.

## Tech Stack

- SwiftUI
- SwiftData
- LocalAuthentication (Face ID / Touch ID)
- UserNotifications
- CryptoKit + Keychain
- NaturalLanguage/CoreML

## Current Features

### Transactions & Budgeting
- Expense / income / loan tracking
- Monthly budgets with progress monitoring
- Recurring monthly budgets
- Optional rollover of unused budget to next month
- Recurring transactions (weekly/monthly)

### Categories & ML
- Automatic category suggestion
- Local adaptive learning from user corrections
- Stronger disambiguation rules for ambiguous terms (e.g. transport vs food)
- No external AI service dependency for categorization

### Multi-Currency
- Popular-currency support with symbols/flags
- User-selectable list of active currencies
- Conversion in list/detail/stats flows

### Savings
- Savings accounts
- Savings goals with progress tracking
- Weekly recommended contribution for goals with deadlines

### Security & Privacy
- App/tab protection with Face ID / Touch ID
- Optional AES-GCM encryption for sensitive notes
- SHA-256 integrity verification
- Encryption key stored in Keychain
- Encryption key rotation with re-encryption of existing notes

### Data Reliability
- SwiftData store persisted at explicit Application Support path
- Versioned schema + migration plan scaffold
- Encrypted local backup snapshot
- Automatic restore when local store is empty

### Export
- Monthly expenses PDF export from Transactions
- Clean, minimal report style with sharing support

## Project Structure

- `Budgify/Models/` data models + schema/migration files
- `Budgify/ViewModels/` business logic
- `Budgify/Services/` currency, ML, security, backup, PDF export
- `Budgify/Views/` feature views by domain

## Roadmap

### Near Term
- Harden SwiftData migration stages with explicit data migration tests
- Extend encryption beyond notes to more sensitive fields
- Improve PDF layout (branding, pagination footer, summary blocks)
- Add internal quality tests for migration, encrypted restore, and ML edge cases

### Mid Term
- Cloud sync strategy (CloudKit)
- Conflict handling and offline-first synchronization improvements
- Advanced analytics and anomaly detection in stats

## Build & Run

1. Open the Xcode project
2. Select an iOS simulator/device
3. Build and run

## Notes

- All sensitive logic is designed to run on-device.
- Backup is encrypted before being written to disk.
- ML adaptation is local and transparent to user workflow.
