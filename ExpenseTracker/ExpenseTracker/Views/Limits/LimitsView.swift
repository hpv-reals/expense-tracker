import SwiftUI
import SwiftData

struct LimitsView: View {
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allTransactions: [Transaction]

    private var limitedCategories: [Category] {
        categories.filter { $0.limitAmount != nil }
    }

    private func spentThisMonth(for category: Category) -> Double {
        let calendar = Calendar.current
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else { return 0 }
        return allTransactions
            .filter { $0.category?.id == category.id && $0.type == .expense && $0.date >= start }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if limitedCategories.isEmpty {
                    ContentUnavailableView(
                        "No budgets set",
                        systemImage: "gauge.with.dots.needle.67percent",
                        description: Text("Set a monthly limit on a category to track it here")
                    )
                } else {
                    ForEach(limitedCategories) { category in
                        LimitRow(category: category, spent: spentThisMonth(for: category))
                    }
                }
            }
            .navigationTitle("Limits")
        }
    }
}
