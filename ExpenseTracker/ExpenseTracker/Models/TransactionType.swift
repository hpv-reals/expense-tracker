import Foundation

/// The kind of money movement a `Transaction` represents.
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"
    case loan = "Loan Given"
    case debt = "Debt/Borrowed"

    var id: String { rawValue }

    /// Compact label for use in segmented controls / chips.
    var shortLabel: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .loan: return "Loan"
        case .debt: return "Debt"
        }
    }

    var systemImage: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .loan: return "arrow.up.right.circle.fill"
        case .debt: return "arrow.down.left.circle.fill"
        }
    }

    /// Whether this type increases (`true`) or decreases (`false`) cash on hand.
    /// Income and borrowed money (debt) add to the wallet; expenses and money
    /// lent out (loan given) take away from it.
    var isPositiveFlow: Bool {
        switch self {
        case .income, .debt: return true
        case .expense, .loan: return false
        }
    }
}
