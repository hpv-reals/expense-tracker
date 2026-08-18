import Foundation
import SwiftData

/// Pre-populates a starter set of categories, adding any that are missing —
/// on first launch (empty store) and on every later launch that introduces
/// new defaults, without touching or duplicating categories that already exist.
enum DefaultDataSeeder {
    /// Old English name → new Vietnamese name, applied once to any category
    /// that still has the old name — renaming in place (not delete + re-add)
    /// so existing transactions stay linked to the same category.
    private static let legacyRenames: [String: String] = [
        "Food": "Ăn uống",
        "Transport": "Xe cộ",
        "Shopping": "Mua sắm",
        "Bills & Utilities": "Hóa đơn & Tiện ích",
        "Entertainment": "Giải trí",
        "Health": "Sức khỏe",
        "Rent": "Tiền nhà",
        "Salary": "Tiền lương",
        "Bonus": "Thưởng",
        "Loan Given": "Cho vay",
        "Debt/Borrowed": "Vay nợ"
    ]

    private static let defaults: [(name: String, icon: String, colorHex: String, type: TransactionType, limit: Double?)] = [
        // Original starter set
        ("Ăn uống", "fork.knife", "#FF9500", .expense, 3_000_000),
        ("Xe cộ", "car.fill", "#5AC8FA", .expense, 1_000_000),
        ("Mua sắm", "bag.fill", "#FF2D55", .expense, 2_000_000),
        ("Hóa đơn & Tiện ích", "bolt.fill", "#FFCC00", .expense, nil),
        ("Giải trí", "gamecontroller.fill", "#AF52DE", .expense, 500_000),
        ("Sức khỏe", "cross.case.fill", "#34C759", .expense, nil),
        ("Tiền nhà", "house.fill", "#8E8E93", .expense, nil),
        ("Tiền lương", "banknote.fill", "#30D158", .income, nil),
        ("Thưởng", "gift.fill", "#32ADE6", .income, nil),
        ("Cho vay", "arrow.up.right.circle.fill", "#FF9F0A", .loan, nil),
        ("Vay nợ", "arrow.down.left.circle.fill", "#FF3B30", .debt, nil),

        // Added to match the user's category list from their previous tracker
        ("Tiền thẻ ĐT", "simcard.fill", "#007AFF", .expense, nil),
        ("Đầu tư kinh doanh", "chart.line.uptrend.xyaxis", "#00A86B", .expense, nil),
        ("Tiền internet", "wifi", "#40C8E0", .expense, nil),
        ("Tiết kiệm", "building.columns.fill", "#00C7BE", .expense, nil),
        ("Tiền nước", "drop.fill", "#64D2FF", .expense, nil),
        ("Đổ xăng", "fuelpump.fill", "#E8601C", .expense, nil),
        ("Tiền phụ cấp", "tray.and.arrow.down.fill", "#5AC8A8", .income, nil),
        ("Làm đẹp", "sparkles", "#FF6FB0", .expense, nil),
        ("Cà phê Trà sữa", "cup.and.saucer.fill", "#A0714A", .expense, nil),
        ("Tiền sửa đồ", "wrench.and.screwdriver.fill", "#A2845E", .expense, nil),
        ("Tổng Hợp", "square.grid.2x2.fill", "#98989D", .expense, nil),
        ("Mục Khác", "ellipsis.circle.fill", "#6E6E73", .expense, nil),
        ("Tiền học", "graduationcap.fill", "#5856D6", .expense, nil),
        ("Phí tài khoản", "creditcard.fill", "#48484A", .expense, nil),
        ("Tiền điện", "bolt.fill", "#FFD60A", .expense, nil),
        ("Mừng cưới", "heart.fill", "#FF375F", .expense, nil)
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        renameLegacyCategoriesIfNeeded(context: context)

        let existingNames = Set((try? context.fetch(FetchDescriptor<Category>()))?.map(\.name) ?? [])
        let missing = defaults.filter { !existingNames.contains($0.name) }
        guard !missing.isEmpty else { return }

        for entry in missing {
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

    /// Renames categories still using an old English name to their Vietnamese
    /// equivalent. Idempotent: once a category is renamed, its old name no
    /// longer exists, so this is a no-op on every later launch.
    @MainActor
    private static func renameLegacyCategoriesIfNeeded(context: ModelContext) {
        guard let categories = try? context.fetch(FetchDescriptor<Category>()) else { return }
        var didRename = false
        for category in categories {
            if let newName = legacyRenames[category.name] {
                category.name = newName
                didRename = true
            }
        }
        if didRename {
            try? context.save()
        }
    }
}
