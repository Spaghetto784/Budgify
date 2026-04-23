import Foundation

struct ExchangeResponse: Decodable {
    let conversion_rates: [String: Double]
}

@Observable
final class CurrencyService {
    struct CurrencyMeta {
        let code: String
        let symbol: String
        let flag: String
    }

    var rates: [String: Double] = [:]
    var lastUpdated: Date?
    private let apiKey = "46159553bb13c9a53d6bc104"

    private let popularCurrencies: [CurrencyMeta] = [
        .init(code: "EUR", symbol: "€", flag: "🇪🇺"),
        .init(code: "USD", symbol: "$", flag: "🇺🇸"),
        .init(code: "GBP", symbol: "£", flag: "🇬🇧"),
        .init(code: "JPY", symbol: "¥", flag: "🇯🇵"),
        .init(code: "CHF", symbol: "Fr", flag: "🇨🇭"),
        .init(code: "CAD", symbol: "C$", flag: "🇨🇦"),
        .init(code: "AUD", symbol: "A$", flag: "🇦🇺"),
        .init(code: "CNY", symbol: "¥", flag: "🇨🇳"),
        .init(code: "INR", symbol: "₹", flag: "🇮🇳"),
        .init(code: "SGD", symbol: "S$", flag: "🇸🇬"),
        .init(code: "THB", symbol: "฿", flag: "🇹🇭")
    ]

    var availableCurrencies: [String] {
        popularCurrencies.map(\.code)
    }

    func fetchRates() async {
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/\(apiKey)/latest/EUR") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeResponse.self, from: data)
            rates = response.conversion_rates
            lastUpdated = .now
        } catch {
            return
        }
    }

    func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        if from == "EUR" {
            return amount * (rates[to] ?? 1)
        }
        if to == "EUR" {
            return amount / (rates[from] ?? 1)
        }
        let inEUR = amount / (rates[from] ?? 1)
        return inEUR * (rates[to] ?? 1)
    }

    func symbol(for currency: String) -> String {
        popularCurrencies.first(where: { $0.code == currency })?.symbol ?? ""
    }

    func flag(for currency: String) -> String {
        popularCurrencies.first(where: { $0.code == currency })?.flag ?? "🏳️"
    }

    func displayLabel(for currency: String) -> String {
        "\(flag(for: currency)) \(currency) \(symbol(for: currency))"
    }

    func uniqueCurrencyPair(primary: String, secondary: String) -> [String] {
        let allowed = Set(availableCurrencies)
        var result: [String] = []

        let normalizedPrimary = allowed.contains(primary) ? primary : "EUR"
        let normalizedSecondary = allowed.contains(secondary) ? secondary : "USD"

        for code in [normalizedPrimary, normalizedSecondary] {
            if !result.contains(code) {
                result.append(code)
            }
        }

        if result.isEmpty {
            return ["EUR"]
        }

        return result
    }
}
