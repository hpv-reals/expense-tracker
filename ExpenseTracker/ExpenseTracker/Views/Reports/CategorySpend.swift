import Foundation

/// One category's total spend for whatever period/filter is currently active
/// in Reports — the data backing both the pie chart's wedges and its legend.
struct CategorySpend: Identifiable {
    let category: Category
    let total: Double
    var id: UUID { category.id }
}
