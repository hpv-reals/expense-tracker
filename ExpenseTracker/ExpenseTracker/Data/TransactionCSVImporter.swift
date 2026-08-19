import Foundation
import SwiftData

/// Imports transactions from a CSV export (columns: STT, Nội dung, Loại
/// thu/chi, Danh mục, Số tiền, Ngày — the shape produced by the user's old
/// tracker app in Excel/Google Sheets). Additive: existing transactions are
/// left alone, rows that already look imported (same amount/date/note/
/// category) are skipped rather than duplicated, and a category name with no
/// existing match is created on the fly rather than failing the whole import.
enum TransactionCSVImporter {
    struct Summary {
        var importedCount = 0
        var skippedDuplicateCount = 0
        var createdCategoryNames: [String] = []
        var rowErrors: [String] = []
    }

    private static let dateFormatters: [DateFormatter] = {
        ["dd-MM-yyyy HH:mm", "dd-MM-yyyy"].map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    @MainActor
    static func importCSV(at url: URL, context: ModelContext) throws -> Summary {
        let needsSecurityScope = url.startAccessingSecurityScopedResource()
        defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }

        let raw = try String(contentsOf: url, encoding: .utf8)
        let rows = parse(csv: raw)

        var categoriesByName: [String: Category] = [:]
        for category in try context.fetch(FetchDescriptor<Category>()) {
            categoriesByName[category.name] = category
        }
        let existing = try context.fetch(FetchDescriptor<Transaction>())
        var existingKeys = Set(existing.map(dedupeKey))

        var summary = Summary()

        for (index, row) in rows.enumerated() {
            let lineNumber = index + 2 // +1 for the header row, +1 for 1-based display

            guard let amount = Double(row.amountText), amount > 0 else {
                summary.rowErrors.append("Dòng \(lineNumber): số tiền không hợp lệ \"\(row.amountText)\"")
                continue
            }
            guard let date = parseDate(row.dateText) else {
                summary.rowErrors.append("Dòng \(lineNumber): ngày không hợp lệ \"\(row.dateText)\"")
                continue
            }
            let categoryName = row.categoryName.trimmingCharacters(in: .whitespaces)
            guard !categoryName.isEmpty else {
                summary.rowErrors.append("Dòng \(lineNumber): thiếu danh mục")
                continue
            }

            let type = transactionType(fromKind: row.kind)
            let category: Category
            if let match = categoriesByName[categoryName] {
                category = match
            } else {
                let created = Category(
                    name: categoryName,
                    iconName: "questionmark.circle",
                    colorHex: "#8E8E93",
                    defaultType: type
                )
                context.insert(created)
                categoriesByName[categoryName] = created
                summary.createdCategoryNames.append(categoryName)
                category = created
            }

            let note = row.note.isEmpty ? nil : row.note
            let key = DedupeKey(amount: amount, date: date, note: note, categoryName: categoryName)
            guard !existingKeys.contains(key) else {
                summary.skippedDuplicateCount += 1
                continue
            }

            context.insert(Transaction(amount: amount, date: date, note: note, type: type, category: category))
            existingKeys.insert(key)
            summary.importedCount += 1
        }

        try context.save()
        return summary
    }

    private static func transactionType(fromKind kind: String) -> TransactionType {
        switch kind.trimmingCharacters(in: .whitespaces) {
        case "Thu": return .income
        case "Cho vay", "Vay": return .loan
        case "Nợ", "Vay nợ": return .debt
        default: return .expense
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private struct DedupeKey: Hashable {
        let amount: Double
        let date: Date
        let note: String?
        let categoryName: String
    }

    private static func dedupeKey(for transaction: Transaction) -> DedupeKey {
        DedupeKey(
            amount: transaction.amount,
            date: transaction.date,
            note: transaction.note,
            categoryName: transaction.category?.name ?? ""
        )
    }

    private struct Row {
        let note: String
        let kind: String
        let categoryName: String
        let amountText: String
        let dateText: String
    }

    /// Minimal CSV parser handling double-quoted fields (with embedded commas)
    /// — enough for this export's shape, not a general-purpose CSV library.
    private static func parse(csv: String) -> [Row] {
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 1 else { return [] }

        var rows: [Row] = []
        for line in lines.dropFirst() {
            let fields = splitCSVLine(String(line))
            guard fields.count >= 6 else { continue }
            rows.append(Row(
                note: fields[1],
                kind: fields[2],
                categoryName: fields[3],
                amountText: fields[4],
                dateText: fields[5]
            ))
        }
        return rows
    }

    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
