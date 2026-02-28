import Foundation
import PDFKit
import UIKit

struct VaultPDFExporter {
    func export(vault: Vault) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(vault.name)-report.pdf")

        let margin: CGFloat = 36
        let contentWidth = pageRect.width - (margin * 2)
        let accent = UIColor.systemBlue

        let appTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.label
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ]

        let itemTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.label
        ]

        let itemDetailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]

        let noteAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.tertiaryLabel
        ]

        let emptyStateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel
        ]

        func drawWrappedText(
            _ text: String,
            at origin: CGPoint,
            width: CGFloat,
            attributes: [NSAttributedString.Key: Any]
        ) -> CGFloat {
            let rect = CGRect(x: origin.x, y: origin.y, width: width, height: .greatestFiniteMagnitude)
            let nsText = NSString(string: text)
            let bounding = nsText.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            ).integral

            nsText.draw(
                with: rect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )

            return max(bounding.height, 1)
        }

        func drawDivider(y: CGFloat) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.systemGray4.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        func drawCard(rect: CGRect) {
            let fill = UIBezierPath(roundedRect: rect, cornerRadius: 14)
            UIColor.secondarySystemBackground.setFill()
            fill.fill()

            let stroke = UIBezierPath(roundedRect: rect, cornerRadius: 14)
            UIColor.systemGray4.setStroke()
            stroke.lineWidth = 1
            stroke.stroke()

            let accentBar = UIBezierPath(
                roundedRect: CGRect(x: rect.minX, y: rect.minY, width: 6, height: rect.height),
                byRoundingCorners: [.topLeft, .bottomLeft],
                cornerRadii: CGSize(width: 14, height: 14)
            )
            accent.setFill()
            accentBar.fill()
        }

        func currencyTotals(for items: [Item]) -> [String: Double] {
            var totals: [String: Double] = [:]
            for item in items {
                guard let amount = item.priceAmount else { continue }
                let currency = (item.priceCurrency?.isEmpty == false ? item.priceCurrency! : CurrencySymbol.euro.rawValue)
                totals[currency, default: 0] += amount
            }
            return totals
        }

        func formattedTotalsText(for items: [Item]) -> String {
            let totals = currencyTotals(for: items)
            if totals.isEmpty { return "—" }

            let parts = totals.keys.sorted().compactMap { currency in
                PriceFormatter.text(amount: totals[currency], currency: currency)
            }
            return parts.joined(separator: "   •   ")
        }

        let sortedItems = vault.items.sorted(by: { $0.expiryDate < $1.expiryDate })

        let currentYear = Calendar.current.component(.year, from: Date())
        let currentYearItems = sortedItems.filter {
            Calendar.current.component(.year, from: $0.expiryDate) == currentYear
        }

        let totalItemsText = "\(sortedItems.count)"
        let currentYearTotalText = formattedTotalsText(for: currentYearItems)
        let allPricedTotalText = formattedTotalsText(for: sortedItems)

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin

                func beginPageIfNeeded(requiredHeight: CGFloat) {
                    if y + requiredHeight > pageRect.height - margin {
                        ctx.beginPage()
                        y = margin
                    }
                }

                ctx.beginPage()

                // App title
                let appTitleHeight = drawWrappedText(
                    "Renewal Vault",
                    at: CGPoint(x: margin, y: y),
                    width: contentWidth,
                    attributes: appTitleAttributes
                )
                y += appTitleHeight + 6

                // Vault header
                let headerText = "\(vault.name) • \(Date().formatted(date: .abbreviated, time: .shortened))"
                let headerHeight = drawWrappedText(
                    headerText,
                    at: CGPoint(x: margin, y: y),
                    width: contentWidth,
                    attributes: subtitleAttributes
                )
                y += headerHeight + 14

                drawDivider(y: y)
                y += 18

                // Totals card
                let totalsCardHeight: CGFloat = 108
                beginPageIfNeeded(requiredHeight: totalsCardHeight + 16)

                let totalsRect = CGRect(x: margin, y: y, width: contentWidth, height: totalsCardHeight)
                drawCard(rect: totalsRect)

                let innerX = totalsRect.minX + 18
                var innerY = totalsRect.minY + 14

                let totalsTitleHeight = drawWrappedText(
                    "vault.export_summary".localized,
                    at: CGPoint(x: innerX, y: innerY),
                    width: totalsRect.width - 36,
                    attributes: sectionTitleAttributes
                )
                innerY += totalsTitleHeight + 8

                _ = drawWrappedText(
                    "\("vault.items_count".localized.replacingOccurrences(of: "%d", with: totalItemsText))",
                    at: CGPoint(x: innerX, y: innerY),
                    width: totalsRect.width - 36,
                    attributes: subtitleAttributes
                )
                innerY += 18

                _ = drawWrappedText(
                    "\("vault.export_current_year_total".localized): \(currentYearTotalText)",
                    at: CGPoint(x: innerX, y: innerY),
                    width: totalsRect.width - 36,
                    attributes: subtitleAttributes
                )
                innerY += 18

                _ = drawWrappedText(
                    "\("vault.export_all_items_total".localized): \(allPricedTotalText)",
                    at: CGPoint(x: innerX, y: innerY),
                    width: totalsRect.width - 36,
                    attributes: subtitleAttributes
                )

                y += totalsCardHeight + 20

                let itemsTitleHeight = drawWrappedText(
                    "vault.export_items".localized,
                    at: CGPoint(x: margin, y: y),
                    width: contentWidth,
                    attributes: sectionTitleAttributes
                )
                y += itemsTitleHeight + 14

                if sortedItems.isEmpty {
                    _ = drawWrappedText(
                        "vault.empty_items".localized,
                        at: CGPoint(x: margin, y: y),
                        width: contentWidth,
                        attributes: emptyStateAttributes
                    )
                } else {
                    for item in sortedItems {
                        let localizedCategory = "category.\(item.category)".localized
                        let priceText = item.formattedPriceText
                        let expiryText = item.expiryDate.formatted(date: .abbreviated, time: .omitted)
                        let noteText = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)

                        let titleLine = item.title
                        let detailParts = [priceText, localizedCategory, expiryText].compactMap { value -> String? in
                            guard let value else { return nil }
                            return value.isEmpty ? nil : value
                        }
                        let detailLine = detailParts.joined(separator: " | ")

                        let titleHeight = NSString(string: titleLine).boundingRect(
                            with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: itemTitleAttributes,
                            context: nil
                        ).integral.height

                        let detailHeight = NSString(string: detailLine).boundingRect(
                            with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: itemDetailAttributes,
                            context: nil
                        ).integral.height

                        let noteHeight: CGFloat
                        if noteText.isEmpty {
                            noteHeight = 0
                        } else {
                            noteHeight = NSString(string: noteText).boundingRect(
                                with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: noteAttributes,
                                context: nil
                            ).integral.height
                        }

                        let cardHeight = max(72, 20 + titleHeight + 6 + detailHeight + (noteText.isEmpty ? 0 : 8 + noteHeight) + 18)
                        beginPageIfNeeded(requiredHeight: cardHeight + 12)

                        let cardRect = CGRect(x: margin, y: y, width: contentWidth, height: cardHeight)
                        drawCard(rect: cardRect)

                        let cardX = cardRect.minX + 18
                        var cardY = cardRect.minY + 14

                        let bulletTitle = "• \(titleLine)"
                        let actualTitleHeight = drawWrappedText(
                            bulletTitle,
                            at: CGPoint(x: cardX, y: cardY),
                            width: cardRect.width - 32,
                            attributes: itemTitleAttributes
                        )
                        cardY += actualTitleHeight + 6

                        let actualDetailHeight = drawWrappedText(
                            detailLine,
                            at: CGPoint(x: cardX + 10, y: cardY),
                            width: cardRect.width - 42,
                            attributes: itemDetailAttributes
                        )
                        cardY += actualDetailHeight

                        if !noteText.isEmpty {
                            cardY += 8
                            _ = drawWrappedText(
                                noteText,
                                at: CGPoint(x: cardX + 10, y: cardY),
                                width: cardRect.width - 42,
                                attributes: noteAttributes
                            )
                        }

                        y += cardHeight + 12
                    }
                }
            }

            return url
        } catch {
            return nil
        }
    }
}
