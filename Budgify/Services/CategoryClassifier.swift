import CoreML
import NaturalLanguage
import Foundation

@Observable
final class CategoryClassifier {
    var isTraining = false
    var modelReady = false

    private var model: NLModel?
    private var learnedExactMatches: [String: String] = [:]
    private var learnedKeywordScores: [String: [String: Int]] = [:]

    // Additional domain keywords
    private let subscriptionKeywords: Set<String> = [
        "abonnement", "subscription", "premium", "plus", "pro", "monthly", "mensuel", "annuel",
        "spotify", "netflix", "icloud", "revolut", "prime", "youtube"
    ]

    private let bankingFeeKeywords: Set<String> = [
        "frais", "fee", "commission", "agios", "banque", "bank", "sepa", "virement", "prélèvement"
    ]

    private let savingsKeywords: Set<String> = [
        "epargne", "épargne", "livret", "la", "lep", "pel", "placement", "compte épargne"
    ]

    private let refundKeywords: Set<String> = [
        "remboursement", "refund", "reversal", "chargeback"
    ]

    private let subscriptionPhrases: [String] = [
        "revolut plus", "revolut premium", "apple icloud", "youtube premium"
    ]

    private let refundPhrases: [String] = [
        "remboursement", "refund"
    ]

    private let exactKey = "classifier.learnedExactMatches.v1"
    private let keywordKey = "classifier.learnedKeywordScores.v1"

    private let transportKeywords: Set<String> = [
        "uber", "taxi", "bolt", "sncf", "train", "metro", "ratp", "navigo", "bus", "tram",
        "avion", "vol", "air", "airport", "ouigo", "thalys", "transilien", "blablacar", "parking",
        "essence", "peage", "autoroute", "gare", "rer", "velib", "scooter"
    ]

    private let foodKeywords: Set<String> = [
        "eats", "deliveroo", "restaurant", "sushi", "pizza", "burger", "mcdonalds", "carrefour",
        "supermarche", "courses", "monoprix", "lidl", "aldi", "franprix", "boulangerie", "starbucks", "cafe"
    ]

    private let transportPhrases: [String] = [
        "uber avion", "uber airport", "uber vol", "uber gare", "uber train"
    ]

    private let foodPhrases: [String] = [
        "uber eats", "just eat"
    ]

    init() {
        loadModel()
        loadLearnedData()
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: "BudgifyClassifier", withExtension: "mlmodelc") else {
            return
        }

        do {
            model = try NLModel(contentsOf: modelURL)
            modelReady = true
        } catch {
            modelReady = false
        }
    }

    func predictedLabel(for title: String) -> String? {
        let cleaned = clean(title)
        guard !cleaned.isEmpty else { return nil }

        // Strong memorized match
        if let exact = learnedExactMatches[cleaned] {
            return exact
        }

        // Try strong learned keywords first
        if let strongLearned = predictedFromLearnedKeywords(cleaned, minimumScore: 3, minimumGap: 1) {
            return strongLearned
        }

        // Heuristics (domain specific)
        if let heuristic = predictedFromHeuristics(cleaned) {
            return heuristic
        }

        // Weaker learned keywords
        if let learned = predictedFromLearnedKeywords(cleaned, minimumScore: 1, minimumGap: 0) {
            return learned
        }

        // Final fallback: NLModel if available
        return model?.predictedLabel(for: cleaned)
    }

    func suggest(for title: String, categories: [Category]) -> Category? {
        let cleaned = clean(title)
        guard !cleaned.isEmpty else { return nil }

        let label = predictedLabel(for: cleaned)
        guard let label else { return nil }

        return categories.first {
            $0.name.lowercased() == label.lowercased() ||
            label.lowercased().contains($0.name.lowercased()) ||
            $0.name.lowercased().contains(label.lowercased())
        }
    }

    func suggestTop(for title: String, categories: [Category], limit: Int = 3) -> [Category] {
        let cleaned = clean(title)
        guard !cleaned.isEmpty, !categories.isEmpty else { return [] }

        // Start with learned keyword scores
        var scores = scoreByCategory(for: cleaned)

        // Boost with heuristics
        if let heuristic = predictedFromHeuristics(cleaned) {
            scores[heuristic, default: 0] += 3
        }

        // Small boost for NLModel label if present
        if let label = model?.predictedLabel(for: cleaned) {
            scores[label, default: 0] += 2
        }

        // Exact memorized match dominates
        if let exact = learnedExactMatches[cleaned] {
            scores[exact, default: 0] += 10
        }

        // Map to existing categories by name (case-insensitive contains/equals)
        let ranked = categories
            .map { cat -> (Category, Int) in
                let key = scores.keys.first(where: { k in
                    k.caseInsensitiveCompare(cat.name) == .orderedSame ||
                    k.lowercased().contains(cat.name.lowercased()) ||
                    cat.name.lowercased().contains(k.lowercased())
                })
                let score = key.flatMap { scores[$0] } ?? 0
                return (cat, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }

        return Array(ranked)
    }

    func suggestWithScores(for title: String, categories: [Category], limit: Int = 3) -> [(Category, Int)] {
        let cleaned = clean(title)
        guard !cleaned.isEmpty, !categories.isEmpty else { return [] }

        var scores = scoreByCategory(for: cleaned)
        if let heuristic = predictedFromHeuristics(cleaned) { scores[heuristic, default: 0] += 3 }
        if let label = model?.predictedLabel(for: cleaned) { scores[label, default: 0] += 2 }
        if let exact = learnedExactMatches[cleaned] { scores[exact, default: 0] += 10 }

        let ranked = categories
            .compactMap { cat -> (Category, Int)? in
                let key = scores.keys.first(where: { k in
                    k.caseInsensitiveCompare(cat.name) == .orderedSame ||
                    k.lowercased().contains(cat.name.lowercased()) ||
                    cat.name.lowercased().contains(k.lowercased())
                })
                guard let key, let score = scores[key] else { return nil }
                return (cat, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)

        return Array(ranked)
    }

    // Naive split predictor: returns categoryName -> ratio (0...1) if a split is suggested
    func predictSplitCategories(for title: String) -> [String: Double]? {
        let cleaned = clean(title)
        guard !cleaned.isEmpty else { return nil }

        // Revolut Plus / Premium: often a mix of Abonnements + Frais bancaires
        if subscriptionPhrases.contains(where: { cleaned.contains($0) }) ||
            cleaned.contains("revolut") && cleaned.contains("plus") {
            return [
                "Abonnements": 0.8,
                "Frais bancaires": 0.2
            ]
        }

        // Refunds are typically single-category (no split)
        if refundPhrases.contains(where: { cleaned.contains($0) }) ||
            refundKeywords.contains(where: { cleaned.contains($0) }) {
            return ["Remboursements": 1.0]
        }

        // PEL / Épargne: single-category suggestion
        if savingsKeywords.contains(where: { cleaned.contains($0) }) {
            return ["Épargne": 1.0]
        }

        // Default: no confident split
        return nil
    }

    func addTrainingSample(title: String, categoryName: String) {
        let cleaned = clean(title)
        guard !cleaned.isEmpty else { return }

        learnedExactMatches[cleaned] = categoryName

        for token in tokens(from: cleaned) {
            var scoreByCategory = learnedKeywordScores[token, default: [:]]
            scoreByCategory[categoryName, default: 0] += 3
            learnedKeywordScores[token] = scoreByCategory
        }

        persistLearnedData()
    }

    func feedback(title: String, predicted: String, actual: String) {
        let cleaned = clean(title)
        guard !cleaned.isEmpty else { return }

        for token in tokens(from: cleaned) {
            var scoreByCategory = learnedKeywordScores[token, default: [:]]
            if let previous = scoreByCategory[predicted], previous > 0 {
                scoreByCategory[predicted] = max(previous - 2, 0)
            }
            scoreByCategory[actual, default: 0] += 5
            learnedKeywordScores[token] = scoreByCategory
        }

        // Also memorize the exact cleaned -> actual mapping for stronger future hits
        if learnedExactMatches[cleaned] != actual {
            learnedExactMatches[cleaned] = actual
        }

        persistLearnedData()
    }

    private func scoreByCategory(for cleaned: String) -> [String: Int] {
        var aggregate: [String: Int] = [:]
        for token in tokens(from: cleaned) {
            guard let scoreByCategory = learnedKeywordScores[token] else { continue }
            for (category, score) in scoreByCategory {
                aggregate[category, default: 0] += score
            }
        }
        return aggregate
    }

    private func predictedFromHeuristics(_ cleaned: String) -> String? {
        // Strong phrase matches first
        for phrase in foodPhrases where cleaned.contains(phrase) { return "Nourriture" }
        for phrase in transportPhrases where cleaned.contains(phrase) { return "Transport" }
        for phrase in subscriptionPhrases where cleaned.contains(phrase) { return "Abonnements" }
        for phrase in refundPhrases where cleaned.contains(phrase) { return "Remboursements" }

        let tokenSet = Set(tokens(from: cleaned))

        let transportHits = tokenSet.intersection(transportKeywords).count
        let foodHits = tokenSet.intersection(foodKeywords).count
        let subscriptionHits = tokenSet.intersection(subscriptionKeywords).count
        let bankingHits = tokenSet.intersection(bankingFeeKeywords).count
        let savingsHits = tokenSet.intersection(savingsKeywords).count
        let refundHits = tokenSet.intersection(refundKeywords).count

        // Select the strongest domain with simple precedence on clear wins
        if refundHits >= 1, refundHits >= max(transportHits, max(foodHits, max(subscriptionHits, max(bankingHits, savingsHits)))) {
            return "Remboursements"
        }
        if subscriptionHits >= 2, subscriptionHits >= max(transportHits, max(foodHits, max(bankingHits, savingsHits))) {
            return "Abonnements"
        }
        if savingsHits >= 1, savingsHits > max(foodHits, max(transportHits, max(subscriptionHits, bankingHits))) {
            return "Épargne"
        }
        if bankingHits >= 1, bankingHits >= max(subscriptionHits, max(transportHits, foodHits)) {
            return "Frais bancaires"
        }
        if transportHits >= 1, transportHits > foodHits { return "Transport" }
        if foodHits >= 2, foodHits >= transportHits { return "Nourriture" }

        return nil
    }

    private func predictedFromLearnedKeywords(_ cleaned: String, minimumScore: Int, minimumGap: Int) -> String? {
        var aggregate: [String: Int] = [:]

        for token in tokens(from: cleaned) {
            guard let scoreByCategory = learnedKeywordScores[token] else { continue }
            for (category, score) in scoreByCategory {
                aggregate[category, default: 0] += score
            }
        }

        guard let best = aggregate.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let sortedScores = aggregate.values.sorted(by: >)
        let secondBest = sortedScores.dropFirst().first ?? 0
        let gap = best.value - secondBest

        guard best.value >= minimumScore, gap >= minimumGap else { return nil }
        return best.key
    }

    private func tokens(from text: String) -> [String] {
        text
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 }
    }

    private func clean(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func loadLearnedData() {
        let defaults = UserDefaults.standard

        if let exact = defaults.dictionary(forKey: exactKey) as? [String: String] {
            learnedExactMatches = exact
        }

        if let keywordData = defaults.dictionary(forKey: keywordKey) as? [String: [String: Int]] {
            learnedKeywordScores = keywordData
        }
    }

    private func persistLearnedData() {
        let defaults = UserDefaults.standard
        defaults.set(learnedExactMatches, forKey: exactKey)
        defaults.set(learnedKeywordScores, forKey: keywordKey)
    }
}

