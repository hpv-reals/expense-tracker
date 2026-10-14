import Foundation
import SwiftData

/// A separate ledger — e.g. "Cá nhân" vs "Doanh nghiệp" — that partitions
/// transactions, budgets, and recurring bills so business and personal
/// spending never mix, while `Category` stays shared across every workspace
/// so the same "Ăn uống" / "Xe cộ" / etc. still works everywhere.
///
/// Exactly one workspace has `isDefault == true` at all times: the one
/// existing data belonged to before this feature existed, and the one
/// that's never offered for deletion (see `WorkspacesView`) so the app
/// always has somewhere to fall back to.
@Model
final class Workspace {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbols name.
    var iconName: String = "person.fill"
    /// Hex color code, e.g. "#007AFF".
    var colorHex: String = "#007AFF"
    var isDefault: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Transaction.workspace)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .cascade, inverse: \RecurringBill.workspace)
    var recurringBills: [RecurringBill]? = []

    @Relationship(deleteRule: .cascade, inverse: \Budget.workspace)
    var budgets: [Budget]? = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isDefault = isDefault
    }
}
