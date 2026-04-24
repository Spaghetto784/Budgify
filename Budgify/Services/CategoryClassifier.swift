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

        if let exact = learnedExactMatches[cleaned] {
            return exact
        }

        if let strongLearned = predictedFromLearnedKeywords(cleaned, minimumScore: 3, minimumGap: 1) {
            return strongLearned
        }

        if let heuristic = predictedFromHeuristics(cleaned) {
            return heuristic
        }

        if let learned = predictedFromLearnedKeywords(cleaned, minimumScore: 1, minimumGap: 0) {
            return learned
        }

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

        learnedExactMatches[cleaned] = actual
        persistLearnedData()
    }

    private func predictedFromHeuristics(_ cleaned: String) -> String? {
        for phrase in foodPhrases where cleaned.contains(phrase) {
            return "Nourriture"
        }

        for phrase in transportPhrases where cleaned.contains(phrase) {
            return "Transport"
        }

        let tokenSet = Set(tokens(from: cleaned))
        let transportHits = tokenSet.intersection(transportKeywords).count
        let foodHits = tokenSet.intersection(foodKeywords).count

        if transportHits >= 1, transportHits > foodHits {
            return "Transport"
        }

        if foodHits >= 2, foodHits >= transportHits {
            return "Nourriture"
        }

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
