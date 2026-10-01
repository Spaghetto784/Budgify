import Foundation
import SwiftUI

/// Comprehensive input validation and sanitization helper
enum InputValidationHelper {
    
    // MARK: - Amount Validation
    
    /// Validates and sanitizes monetary amounts with edge case handling
    static func validateAmount(_ input: String, allowNegative: Bool = false, maxValue: Double = 1_000_000_000) -> ValidationResult<Double> {
        // Remove whitespace
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        
        // Check for empty input
        guard !trimmed.isEmpty else {
            return .invalid("Le montant ne peut pas être vide")
        }
        
        // Handle multiple decimal separators
        let commaCount = trimmed.filter { $0 == "," }.count
        let dotCount = trimmed.filter { $0 == "." }.count
        
        guard commaCount + dotCount <= 1 else {
            return .invalid("Format invalide : plusieurs séparateurs décimaux")
        }
        
        // Normalize decimal separator
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        
        // Parse to double
        guard let value = Double(normalized) else {
            return .invalid("Format de nombre invalide")
        }
        
        // Check for NaN or Infinity
        guard value.isFinite else {
            return .invalid("Valeur numérique invalide")
        }
        
        // Check negative values
        if !allowNegative && value < 0 {
            return .invalid("Le montant ne peut pas être négatif")
        }
        
        // Check for zero
        if value == 0 {
            return .warning("Le montant est zéro", value: value)
        }
        
        // Check maximum value
        if abs(value) > maxValue {
            return .invalid("Le montant dépasse la limite maximale (\(maxValue.formatted()))")
        }
        
        // Check for too many decimal places
        let components = normalized.split(separator: ".")
        if components.count == 2 {
            let decimals = components[1]
            if decimals.count > 2 {
                let rounded = round(value * 100) / 100
                return .warning("Arrondi à 2 décimales", value: rounded)
            }
        }
        
        return .valid(value)
    }
    
    // MARK: - Text Validation
    
    /// Validates transaction titles
    static func validateTitle(_ input: String, maxLength: Int = 100) -> ValidationResult<String> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("Le titre ne peut pas être vide")
        }
        
        guard trimmed.count <= maxLength else {
            return .invalid("Le titre est trop long (max \(maxLength) caractères)")
        }
        
        // Check for suspicious patterns
        if trimmed.count < 2 {
            return .warning("Le titre est très court", value: trimmed)
        }
        
        // Remove control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        
        return .valid(sanitized)
    }
    
    /// Validates category names
    static func validateCategoryName(_ input: String, existingNames: [String] = []) -> ValidationResult<String> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return .invalid("Le nom de catégorie ne peut pas être vide")
        }
        
        guard trimmed.count <= 50 else {
            return .invalid("Le nom est trop long (max 50 caractères)")
        }
        
        // Check for duplicates (case-insensitive)
        if existingNames.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            return .invalid("Une catégorie avec ce nom existe déjà")
        }
        
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        return .valid(sanitized)
    }
    
    // MARK: - Date Validation
    
    /// Validates dates with reasonable bounds
    static func validateDate(_ date: Date, allowFuture: Bool = true, maxYearsInPast: Int = 10) -> ValidationResult<Date> {
        let now = Date()
        let calendar = Calendar.current
        
        // Check if date is in the future
        if !allowFuture && date > now {
            return .warning("La date est dans le futur", value: date)
        }
        
        // Check if date is too far in the past
        if let minDate = calendar.date(byAdding: .year, value: -maxYearsInPast, to: now),
           date < minDate {
            return .warning("La date est très ancienne (>\(maxYearsInPast) ans)", value: date)
        }
        
        // Check if date is too far in the future
        if let maxDate = calendar.date(byAdding: .year, value: 10, to: now),
           date > maxDate {
            return .invalid("La date ne peut pas être si lointaine (>10 ans)")
        }
        
        return .valid(date)
    }
    
    // MARK: - Currency Validation
    
    /// Validates currency conversion
    static func validateConversion(amount: Double, from: String, to: String, rate: Double) -> ValidationResult<Double> {
        guard from != to else {
            return .valid(amount)
        }
        
        guard rate > 0 && rate.isFinite else {
            return .invalid("Taux de change invalide")
        }
        
        let converted = amount * rate
        
        guard converted.isFinite else {
            return .invalid("Erreur de conversion")
        }
        
        if converted > 1_000_000_000 {
            return .warning("Le montant converti est très élevé", value: converted)
        }
        
        return .valid(converted)
    }
    
    // MARK: - Budget Validation
    
    /// Validates budget limits
    static func validateBudgetLimit(_ amount: Double, spent: Double = 0) -> ValidationResult<Double> {
        guard amount > 0 else {
            return .invalid("La limite du budget doit être positive")
        }
        
        guard amount.isFinite else {
            return .invalid("Valeur invalide")
        }
        
        if amount < spent && spent > 0 {
            return .warning("La limite est inférieure aux dépenses actuelles (\(spent.formatted()))", value: amount)
        }
        
        if amount > 1_000_000 {
            return .warning("La limite est très élevée", value: amount)
        }
        
        return .valid(amount)
    }
    
    // MARK: - Split Validation
    
    /// Validates transaction splits
    static func validateSplits(_ splits: [(categoryName: String, amount: String)], totalAmount: Double) -> ValidationResult<[CategorySplit]> {
        guard !splits.isEmpty else {
            return .invalid("Aucune répartition définie")
        }
        
        var validSplits: [CategorySplit] = []
        var splitTotal: Double = 0
        
        for split in splits {
            // Validate category name
            guard !split.categoryName.isEmpty else {
                return .invalid("Toutes les catégories doivent être sélectionnées")
            }
            
            // Validate amount
            let amountResult = validateAmount(split.amount, allowNegative: true)
            switch amountResult {
            case .valid(let amount):
                validSplits.append(CategorySplit(categoryName: split.categoryName, amount: amount))
                splitTotal += amount
            case .invalid(let message):
                return .invalid("Erreur dans la répartition : \(message)")
            case .warning(let message, let amount):
                validSplits.append(CategorySplit(categoryName: split.categoryName, amount: amount))
                splitTotal += amount
            }
        }
        
        // Check if splits sum equals total (with tolerance)
        let difference = abs(splitTotal - totalAmount)
        let tolerance = max(0.01, abs(totalAmount) * 0.001) // 0.1% or 1 cent
        
        if difference > tolerance {
            return .warning(
                "La somme des répartitions (\(splitTotal.formatted())) diffère du total (\(totalAmount.formatted())). Normalisation recommandée.",
                value: validSplits
            )
        }
        
        return .valid(validSplits)
    }
    
    // MARK: - Tag Validation
    
    /// Validates and sanitizes tags
    static func validateTags(_ input: String, maxTags: Int = 10, maxTagLength: Int = 30) -> ValidationResult<[String]> {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .valid([])
        }
        
        let tags = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        
        guard tags.count <= maxTags else {
            return .invalid("Trop de tags (max \(maxTags))")
        }
        
        for tag in tags {
            if tag.count > maxTagLength {
                return .invalid("Un tag est trop long (max \(maxTagLength) caractères)")
            }
        }
        
        // Remove duplicates
        let uniqueTags = Array(Set(tags))
        
        if uniqueTags.count < tags.count {
            return .warning("Tags dupliqués supprimés", value: uniqueTags)
        }
        
        return .valid(uniqueTags)
    }
}

// MARK: - Validation Result Type

enum ValidationResult<T> {
    case valid(T)
    case warning(String, value: T)
    case invalid(String)
    
    var isValid: Bool {
        switch self {
        case .valid, .warning: return true
        case .invalid: return false
        }
    }
    
    var value: T? {
        switch self {
        case .valid(let val), .warning(_, let val): return val
        case .invalid: return nil
        }
    }
    
    var message: String? {
        switch self {
        case .warning(let msg, _), .invalid(let msg): return msg
        case .valid: return nil
        }
    }
}

// MARK: - SwiftUI Extensions

extension View {
    /// Shows a validation alert if needed
    func validationAlert(result: Binding<ValidationResult<Any>?>) -> some View {
        self.alert("Validation", isPresented: .constant(result.wrappedValue != nil)) {
            Button("OK") {
                result.wrappedValue = nil
            }
        } message: {
            if let message = result.wrappedValue?.message {
                Text(message)
            }
        }
    }
}

// MARK: - Error Handling Extensions

extension Double {
    /// Safe formatting with fallback
    var safeFormatted: String {
        guard self.isFinite else { return "N/A" }
        return String(format: "%.2f", self)
    }
}

extension String {
    /// Sanitizes input for safe storage
    var sanitized: String {
        self.components(separatedBy: .controlCharacters).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Checks if string contains only valid characters
    var isSafeInput: Bool {
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .union(CharacterSet(charactersIn: "€$£¥@#"))
        
        return self.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
}
