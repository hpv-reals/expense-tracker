import Foundation

/// Shared month-to-date spend calculation, used by the Limits tab and by the
/// over-budget check that runs right after saving a new expense.
enum BudgetChecker {
    /// Total expense amount recorded for `category` within the calendar month containing `reference`.
    static func spentThisMonth(
        for category: Category,
        transactions: [Transaction],
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: reference)) else { return 0 }
        return transactions
            .filter { $0.category?.id == category.id && $0.type == .expense && $0.date >= start }
            .reduce(0) { $0 + $1.amount }
    }
}
