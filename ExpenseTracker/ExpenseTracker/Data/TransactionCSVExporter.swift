import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Exports transactions to the "Nếp" CSV template (columns: Ngày giờ, Loại,
/// Số tiền (VND), Danh mục, Tên người nhận, Nguồn chi, Trạng thái, Ghi chú,
/// Đến tài khoản). `TransactionCSVImporter` reads the same shape back.
enum TransactionCSVExporter {
    static let header = [
        "Ngày giờ", "Loại", "Số tiền (VND)", "Danh mục", "Tên người nhận",
        "Nguồn chi", "Trạng thái", "Ghi chú", "Đến tài khoản"
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Oldest first, like a ledger. Prefixed with a UTF-8 BOM so Excel opens
    /// the Vietnamese text with the right encoding instead of mojibake.
    static func csv(for transactions: [Transaction]) -> String {
        var lines = [header.map(escape).joined(separator: ",")]

        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let fields = [
                dateFormatter.string(from: transaction.date),
                transaction.type.csvKind,
                amountText(transaction.amount),
                transaction.category?.name ?? "",
                transaction.recipientName ?? "",
                transaction.sourceName ?? "",
                transaction.type.csvStatus(isSettled: transaction.isSettled),
                transaction.note ?? "",
                transaction.destinationAccount ?? ""
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }

        return "\u{FEFF}" + lines.joined(separator: "\n") + "\n"
    }

    private static func amountText(_ amount: Double) -> String {
        amount.rounded() == amount ? String(Int64(amount)) : String(amount)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// Wraps the generated CSV so `.fileExporter` can write it.
struct TransactionCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
