import CoreML
import NaturalLanguage
import Foundation

@Observable
final class CategoryClassifier {
    var isTraining = false
    var modelReady = false
    private var model: NLModel?

    init() {
        loadModel()
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: "BudgifyClassifier", withExtension: "mlmodelc") ??
              Bundle.main.url(forResource: "BudgifyClassifier", withExtension: "mlmodel") else { return }
        do {
            let compiledURL = try MLModel.compileModel(at: modelURL)
            let mlModel = try MLModel(contentsOf: compiledURL)
            model = try NLModel(mlModel: mlModel)
            modelReady = true
        } catch {
            modelReady = false
        }
    }

    func suggest(for title: String, categories: [Category]) -> Category? {
        let cleaned = clean(title)
        guard !cleaned.isEmpty else { return nil }

        if let model = model, modelReady {
            let predicted = model.predictedLabel(for: cleaned)
            return categories.first {
                $0.name.lowercased() == predicted?.lowercased() ||
                predicted?.lowercased().contains($0.name.lowercased()) == true
            }
        }
        return rulesBasedSuggestion(for: title, categories: categories)
    }

    func addTrainingSample(title: String, categoryName: String) {
        // stocké pour future version avec MLUpdateTask
    }

    func feedback(title: String, predicted: String, actual: String) {
        addTrainingSample(title: title, categoryName: actual)
    }

    private func rulesBasedSuggestion(for title: String, categories: [Category]) -> Category? {
        let lower = title.lowercased()
        let rules: [String: [String]] = [
            "nourriture": ["uber eats", "mcdo", "carrefour", "monoprix", "restaurant", "lidl", "aldi", "deliveroo"],
            "transport": ["uber", "sncf", "ratp", "metro", "air france", "blablacar", "bolt", "vélib"],
            "logement": ["loyer", "edf", "gaz", "internet", "bouygues", "sfr", "orange", "eau"],
            "loisirs": ["netflix", "spotify", "disney", "steam", "playstation", "xbox", "cinema"],
            "santé": ["pharmacie", "médecin", "docteur", "clinique", "dentiste", "mutuelle"],
            "shopping": ["amazon", "zalando", "h&m", "zara", "fnac", "decathlon"],
            "éducation": ["udemy", "coursera", "livre", "formation", "école", "université"]
        ]
        for (categoryKeyword, keywords) in rules {
            for keyword in keywords {
                if lower.contains(keyword) {
                    return categories.first {
                        $0.name.lowercased().contains(categoryKeyword) ||
                        categoryKeyword.contains($0.name.lowercased())
                    }
                }
            }
        }
        return nil
    }

    private func clean(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .punctuationCharacters).joined(separator: " ")
    }
}   
