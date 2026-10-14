import Foundation
import SwiftData

/// Imports transactions from CSV. Two shapes are recognised by their header:
///
/// - the "Nếp" template written by `TransactionCSVExporter` — Ngày giờ, Loại,
///   Số tiền (VND), Danh mục, Tên người nhận, Nguồn chi, Trạng thái, Ghi chú,
///   Đến tài khoản (columns are matched by name, so order doesn't matter and
///   the last five are optional);
/// - the old tracker app's export — STT, Nội dung, Loại thu/chi, Danh mục,
///   Số tiền, Ngày (fixed positions).
///
/// Additive: existing transactions are left alone, rows that already look
/// imported (same type/amount/minute/note/category) are skipped rather than
/// duplicated, and a category name with no existing match is created on the
/// fly rather than failing the whole import.
enum TransactionCSVImporter {
    struct Summary {
        var importedCount = 0
        var skippedDuplicateCount = 0
        var createdCategoryNames: [String] = []
        var rowErrors: [String] = []
    }

    private static let dateFormatters: [DateFormatter] = {
        [
            "dd/MM/yyyy HH:mm", "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy",
            "dd-MM-yyyy HH:mm", "dd-MM-yyyy HH:mm:ss", "dd-MM-yyyy",
            "yyyy-MM-dd HH:mm", "yyyy-MM-dd"
        ].map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    /// - Parameter workspace: which ledger the imported rows are attached to
    ///   — every created `Transaction` belongs to this workspace, and
    ///   duplicate-detection only looks at transactions already in it (the
    ///   same CSV re-imported into a different workspace isn't a duplicate).
    @MainActor
    static func importCSV(at url: URL, context: ModelContext, workspace: Workspace?) throws -> Summary {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }

        let raw = try String(contentsOf: url, encoding: .utf8)
        let (rows, headerError) = parse(csv: raw)

        var summary = Summary()
        if let headerError {
            summary.rowErrors.append(headerError)
            return summary
        }

        var categoriesByName: [String: Category] = [:]
        for category in try context.fetch(FetchDescriptor<Category>()) {
            categoriesByName[category.name] = category
        }
        let existing = try context.fetch(FetchDescriptor<Transaction>())
            .filter { $0.workspace?.id == workspace?.id }
        var existingKeys = Set(existing.map(dedupeKey))

        for row in rows {
            guard let amount = parseAmount(row.amountText), amount > 0 else {
                summary.rowErrors.append("Dòng \(row.lineNumber): số tiền không hợp lệ \"\(row.amountText)\"")
                continue
            }
            guard let date = parseDate(row.dateText) else {
                summary.rowErrors.append("Dòng \(row.lineNumber): ngày không hợp lệ \"\(row.dateText)\"")
                continue
            }
            guard let type = row.type else {
                summary.rowErrors.append("Dòng \(row.lineNumber): loại không hợp lệ \"\(row.kindText)\"")
                continue
            }
            guard !row.categoryName.isEmpty else {
                summary.rowErrors.append("Dòng \(row.lineNumber): thiếu danh mục")
                continue
            }

            let note = row.note.isEmpty ? nil : row.note
            let key = DedupeKey(
                type: type,
                amount: amount,
                minute: minute(of: date),
                note: note,
                categoryName: row.categoryName
            )
            guard !existingKeys.contains(key) else {
                summary.skippedDuplicateCount += 1
                continue
            }

            let category: Category
            if let match = categoriesByName[row.categoryName] {
                category = match
            } else {
                let created = Category(
                    name: row.categoryName,
                    iconName: "questionmark.circle",
                    colorHex: "#8E8E93",
                    // Transfers have no category of their own; file the new one
                    // under expenses so it shows up somewhere sensible.
                    defaultType: type == .transfer ? .expense : type
                )
                context.insert(created)
                categoriesByName[row.categoryName] = created
                summary.createdCategoryNames.append(row.categoryName)
                category = created
            }

            context.insert(Transaction(
                amount: amount,
                date: date,
                note: note,
                type: type,
                category: category,
                workspace: workspace,
                recipientName: row.recipient.isEmpty ? nil : row.recipient,
                sourceName: row.source.isEmpty ? nil : row.source,
                destinationAccount: row.destination.isEmpty ? nil : row.destination,
                isSettled: TransactionType.isSettled(csvStatus: row.status)
            ))
            existingKeys.insert(key)
            summary.importedCount += 1
        }

        try context.save()
        return summary
    }

    // MARK: - Parsing helpers

    private static func parseDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// Plain numbers, plus grouped ones like "1.500.000" / "1,500,000" that
    /// Excel produces when a cell is formatted as text.
    private static func parseAmount(_ text: String) -> Double? {
        let compact = text.filter { !$0.isWhitespace }
        if let value = Double(compact) { return value }
        guard compact.range(of: #"^\d{1,3}([.,]\d{3})+$"#, options: .regularExpression) != nil else { return nil }
        return Double(compact.filter { $0 != "." && $0 != "," })
    }

    private static func minute(of date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 60).rounded(.down))
    }

    /// Minute precision because the template's "Ngày giờ" has no seconds — a
    /// transaction exported and re-imported must still count as a duplicate.
    private struct DedupeKey: Hashable {
        let type: TransactionType
        let amount: Double
        let minute: Int
        let note: String?
        let categoryName: String
    }

    private static func dedupeKey(for transaction: Transaction) -> DedupeKey {
        DedupeKey(
            type: transaction.type,
            amount: transaction.amount,
            minute: minute(of: transaction.date),
            note: transaction.note,
            categoryName: transaction.category?.name ?? ""
        )
    }

    private struct Row {
        let lineNumber: Int
        /// `nil` when the kind text isn't recognised (template files only —
        /// the old format treats anything unknown as an expense).
        let type: TransactionType?
        let kindText: String
        let categoryName: String
        let amountText: String
        let dateText: String
        var note = ""
        var recipient = ""
        var source = ""
        var destination = ""
        var status = ""
    }

    /// Returns the data rows, or an error message when the header matches
    /// neither supported shape.
    private static func parse(csv: String) -> (rows: [Row], headerError: String?) {
        let records = parseRecords(csv)
        guard let header = records.first else { return ([], nil) }

        let names = header.map(TransactionType.fold)
        if names.first == "ngay gio" {
            return parseTemplate(records: records, headerNames: names)
        }
        return (parseLegacy(records: records), nil)
    }

    private static func parseTemplate(records: [[String]], headerNames: [String]) -> ([Row], String?) {
        func column(_ prefix: String) -> Int? { headerNames.firstIndex { $0.hasPrefix(prefix) } }

        guard let dateColumn = column("ngay gio"),
              let kindColumn = column("loai"),
              let amountColumn = column("so tien"),
              let categoryColumn = column("danh muc") else {
            return ([], "File thiếu cột bắt buộc (Ngày giờ, Loại, Số tiền, Danh mục)")
        }
        let recipientColumn = column("ten nguoi nhan")
        let sourceColumn = column("nguon chi")
        let statusColumn = column("trang thai")
        let noteColumn = column("ghi chu")
        let destinationColumn = column("den tai khoan")

        var rows: [Row] = []
        for (index, record) in records.enumerated().dropFirst() {
            func value(_ column: Int?) -> String {
                guard let column, column < record.count else { return "" }
                return record[column].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let kindText = value(kindColumn)
            rows.append(Row(
                lineNumber: index + 1,
                type: TransactionType(csvKind: kindText),
                kindText: kindText,
                categoryName: value(categoryColumn),
                amountText: value(amountColumn),
                dateText: value(dateColumn),
                note: value(noteColumn),
                recipient: value(recipientColumn),
                source: value(sourceColumn),
                destination: value(destinationColumn),
                status: value(statusColumn)
            ))
        }
        return (rows, nil)
    }

    /// Old tracker app shape: STT, Nội dung, Loại thu/chi, Danh mục, Số tiền, Ngày.
    private static func parseLegacy(records: [[String]]) -> [Row] {
        var rows: [Row] = []
        for (index, fields) in records.enumerated().dropFirst() {
            guard fields.count >= 6 else { continue }
            let kindText = fields[2].trimmingCharacters(in: .whitespaces)
            rows.append(Row(
                lineNumber: index + 1,
                type: TransactionType(csvKind: kindText) ?? .expense,
                kindText: kindText,
                categoryName: fields[3].trimmingCharacters(in: .whitespaces),
                amountText: fields[4],
                dateText: fields[5],
                note: fields[1]
            ))
        }
        return rows
    }

    /// RFC 4180-style parser: quoted fields may hold commas, line breaks and
    /// `""` escapes; a leading BOM (Excel's UTF-8 CSV) is dropped; blank
    /// records are skipped.
    private static func parseRecords(_ text: String) -> [[String]] {
        let characters = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)

        var records: [[String]] = []
        var fields: [String] = []
        var current = ""
        var insideQuotes = false

        func endRecord() {
            fields.append(current)
            current = ""
            if fields.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                records.append(fields)
            }
            fields = []
        }

        var index = 0
        while index < characters.count {
            let char = characters[index]
            if insideQuotes {
                if char == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        current.append("\"")
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                insideQuotes = true
            } else if char == "," {
                fields.append(current)
                current = ""
            } else if char == "\n" || char == "\r" || char == "\r\n" {
                endRecord()
            } else {
                current.append(char)
            }
            index += 1
        }
        endRecord()
        return records
    }
}
