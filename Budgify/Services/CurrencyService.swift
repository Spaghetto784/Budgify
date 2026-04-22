import Foundation

struct ExchangeResponse: Decodable {
    let conversion_rates: [String: Double]
}

@Observable
final class CurrencyService {
    var rates: [String: Double] = [:]
    var lastUpdated: Date?
    private let apiKey = "VOTRE_CLE_ICI"

    func fetchRates() async {
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/\("46159553bb13c9a53d6bc104")/latest/EUR") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeResponse.self, from: data)
            rates = response.conversion_rates.filter { ["EUR", "THB"].contains($0.key) }
            lastUpdated = .now
        } catch {
            return
        }
    }

    func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        if from == "EUR", let rate = rates["THB"] {
            return amount * rate
        }
        if from == "THB", let rate = rates["THB"] {
            return amount / rate
        }
        return amount
    }
}
