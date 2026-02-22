import Foundation
import PDFKit
import UIKit

struct VaultPDFExporter {
    func export(vault: Vault) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(vault.name)-report.pdf")
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let header = "\(vault.name) - \(Date().formatted(date: .abbreviated, time: .shortened))"
                header.draw(at: CGPoint(x: 36, y: 36), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
                var y: CGFloat = 80
                for item in vault.items.sorted(by: { $0.expiryDate < $1.expiryDate }) {
                    let line = "• \(item.title) | \(item.category) | \(item.expiryDate.formatted(date: .abbreviated, time: .omitted))"
                    line.draw(at: CGPoint(x: 36, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
                    y += 18
                    if y > 800 { ctx.beginPage(); y = 36 }
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
