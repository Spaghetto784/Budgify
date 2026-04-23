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

        if let voted = predictedFromLearnedKeywords(cleaned) {
            return voted
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
            scoreByCategory[categoryName, default: 0] += 1
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
                scoreByCategory[predicted] = previous - 1
            }
            scoreByCategory[actual, default: 0] += 2
            learnedKeywordScores[token] = scoreByCategory
        }

        learnedExactMatches[cleaned] = actual
        persistLearnedData()
    }

    private func predictedFromLearnedKeywords(_ cleaned: String) -> String? {
        var aggregate: [String: Int] = [:]

        for token in tokens(from: cleaned) {
            guard let scoreByCategory = learnedKeywordScores[token] else { continue }
            for (category, score) in scoreByCategory {
                aggregate[category, default: 0] += score
            }
        }

        return aggregate.max(by: { $0.value < $1.value })?.key
    }

    private func tokens(from text: String) -> [String] {
        text
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 }
    }

    private func clean(_ text: String) -> String {
        text.lowercased()
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
