import Foundation
import SwiftData

/// Pre-populates a starter set of categories the very first time the app launches.
enum DefaultDataSeeder {
    private static let defaults: [(name: String, icon: String, colorHex: String, type: TransactionType, limit: Double?)] = [
        ("Food", "fork.knife", "#FF9500", .expense, 3_000_000),
        ("Transport", "car.fill", "#5AC8FA", .expense, 1_000_000),
        ("Shopping", "bag.fill", "#FF2D55", .expense, 2_000_000),
        ("Bills & Utilities", "bolt.fill", "#FFCC00", .expense, nil),
        ("Entertainment", "gamecontroller.fill", "#AF52DE", .expense, 500_000),
        ("Health", "cross.case.fill", "#34C759", .expense, nil),
        ("Rent", "house.fill", "#8E8E93", .expense, nil),
        ("Salary", "banknote.fill", "#30D158", .income, nil),
        ("Bonus", "gift.fill", "#32ADE6", .income, nil),
        ("Loan Given", "arrow.up.right.circle.fill", "#FF9F0A", .loan, nil),
        ("Debt/Borrowed", "arrow.down.left.circle.fill", "#FF3B30", .debt, nil)
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for entry in defaults {
            let category = Category(
                name: entry.name,
                iconName: entry.icon,
                colorHex: entry.colorHex,
                defaultType: entry.type,
                limitAmount: entry.limit
            )
            context.insert(category)
        }

        try? context.save()
    }
}
