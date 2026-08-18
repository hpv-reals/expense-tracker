import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbols name.
    var iconName: String = "questionmark.circle"
    /// Hex color code, e.g. "#FF9500".
    var colorHex: String = "#8E8E93"
    var defaultType: TransactionType = TransactionType.expense
    /// Optional monthly spending limit. `nil` means no budget tracking.
    var limitAmount: Double?

    /// Deleting a category deletes every transaction that belongs to it.
    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        defaultType: TransactionType,
        limitAmount: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.defaultType = defaultType
        self.limitAmount = limitAmount
    }
}
