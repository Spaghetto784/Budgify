import Foundation
import UIKit

@Observable
final class ExpensePDFService {
    func exportMonthlyExpensesPDF(
        transactions: [Transaction],
        month: Date,
        displayCurrency: String,
        rates: [String: Double],
        symbolProvider: (String) -> String
    ) -> URL? {
        let calendar = Calendar.current
        let expenses = transactions
            .filter {
                !$0.isRecurringTemplate &&
                $0.type == .expense &&
                calendar.isDate($0.date, equalTo: month, toGranularity: .month)
            }
            .sorted { $0.date < $1.date }

        let total = expenses.reduce(0.0) { partial, transaction in
            partial + converted(amount: transaction.amount, from: transaction.currency, to: displayCurrency, rates: rates)
        }

        let fileName = "Budgify-Depenses-\(monthKey(from: month)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()

                let margin: CGFloat = 40
                var y: CGFloat = margin
                let symbol = symbolProvider(displayCurrency)

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
                let subtitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let headerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor.label
                ]
                let rowAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.label
                ]

                let title = "Budgify - Dépenses mensuelles"
                title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
                y += 30

                let monthText = "Mois: \(month.formatted(.dateTime.month(.wide).year()))"
                monthText.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
                y += 18

                let totalText = "Total: \(symbol)\(String(format: "%.2f", total))"
                totalText.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
                y += 26

                let separator = UIBezierPath()
                separator.move(to: CGPoint(x: margin, y: y))
                separator.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                UIColor.systemGray4.setStroke()
                separator.lineWidth = 1
                separator.stroke()
                y += 12

                "Date".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
                "Libellé".draw(at: CGPoint(x: margin + 90, y: y), withAttributes: headerAttrs)
                "Catégorie".draw(at: CGPoint(x: margin + 270, y: y), withAttributes: headerAttrs)
                "Montant".draw(at: CGPoint(x: pageRect.width - margin - 90, y: y), withAttributes: headerAttrs)
                y += 16

                let headSep = UIBezierPath()
                headSep.move(to: CGPoint(x: margin, y: y))
                headSep.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                UIColor.systemGray4.setStroke()
                headSep.lineWidth = 0.8
                headSep.stroke()
                y += 10

                if expenses.isEmpty {
                    let empty = "Aucune dépense pour ce mois."
                    empty.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
                } else {
                    for transaction in expenses {
                        if y > pageRect.height - margin - 40 {
                            context.beginPage()
                            y = margin
                        }

                        let amount = converted(amount: transaction.amount, from: transaction.currency, to: displayCurrency, rates: rates)
                        let dateText = transaction.date.formatted(date: .abbreviated, time: .omitted)
                        let categoryText = transaction.resolvedCategoryName ?? "-"
                        let amountText = "\(symbol)\(String(format: "%.2f", amount))"

                        dateText.draw(at: CGPoint(x: margin, y: y), withAttributes: rowAttrs)
                        transaction.title.draw(at: CGPoint(x: margin + 90, y: y), withAttributes: rowAttrs)
                        categoryText.draw(at: CGPoint(x: margin + 270, y: y), withAttributes: rowAttrs)
                        amountText.draw(at: CGPoint(x: pageRect.width - margin - 90, y: y), withAttributes: rowAttrs)
                        y += 16
                    }
                }
            }

            return url
        } catch {
            return nil
        }
    }

    private func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func converted(amount: Double, from: String, to: String, rates: [String: Double]) -> Double {
        guard from != to else { return amount }
        if from == "EUR" { return amount * (rates[to] ?? 1) }
        if to == "EUR" { return amount / (rates[from] ?? 1) }
        let inEUR = amount / (rates[from] ?? 1)
        return inEUR * (rates[to] ?? 1)
    }
}
