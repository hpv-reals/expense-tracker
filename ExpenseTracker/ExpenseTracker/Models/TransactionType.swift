import Foundation

/// The kind of money movement a `Transaction` represents.
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"
    case loan = "Loan Given"
    case debt = "Debt/Borrowed"
    /// Moving money between the user's own accounts (e.g. paying off a card).
    case transfer = "Transfer"

    var id: String { rawValue }

    /// Compact label for use in segmented controls / chips.
    var shortLabel: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .loan: return "Loan"
        case .debt: return "Debt"
        case .transfer: return "Transfer"
        }
    }

    var systemImage: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .loan: return "arrow.up.right.circle.fill"
        case .debt: return "arrow.down.left.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    /// Whether this type increases (`true`) or decreases (`false`) cash on hand.
    /// Income and borrowed money (debt) add to the wallet; expenses and money
    /// lent out (loan given) take away from it.
    var isPositiveFlow: Bool {
        switch self {
        case .income, .debt: return true
        case .expense, .loan, .transfer: return false
        }
    }

    /// Transfers aren't tied to a spending/income category, so any category
    /// may be attached; every other type only offers its own categories.
    func accepts(_ category: Category) -> Bool {
        self == .transfer || category.defaultType == self
    }

    // MARK: - CSV template vocabulary

    /// "Loại" column of the CSV template.
    var csvKind: String {
        switch self {
        case .income: return "Thu"
        case .expense: return "Chi"
        case .transfer: return "Chuyển"
        case .loan: return "Cho vay"
        case .debt: return "Vay nợ"
        }
    }

    /// Accepts the template's names plus the old tracker's ("Vay", "Nợ"),
    /// ignoring case and diacritics. `nil` for anything unrecognised.
    init?(csvKind: String) {
        switch Self.fold(csvKind) {
        case "thu": self = .income
        case "chi": self = .expense
        case "chuyen", "chuyen khoan": self = .transfer
        case "cho vay", "vay": self = .loan
        case "no", "vay no": self = .debt
        default: return nil
        }
    }

    /// "Trạng thái" column: "Đã thu"/"Đã thanh toán", or "Chưa …" while pending.
    func csvStatus(isSettled: Bool) -> String {
        let received = self == .income || self == .debt
        switch (received, isSettled) {
        case (true, true): return "Đã thu"
        case (true, false): return "Chưa thu"
        case (false, true): return "Đã thanh toán"
        case (false, false): return "Chưa thanh toán"
        }
    }

    /// Anything starting with "Chưa" is pending; blank or "Đã …" is settled.
    static func isSettled(csvStatus: String) -> Bool {
        !fold(csvStatus).hasPrefix("chua")
    }

    static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi"))
            // "đ" has no decomposition, so diacritic folding leaves it alone.
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
    }
}
