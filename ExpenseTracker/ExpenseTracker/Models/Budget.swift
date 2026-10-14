import Foundation
import SwiftData

/// A monthly spending limit on one category, scoped to one workspace — the
/// same shared `Category` can carry a different limit (or none at all) in
/// each workspace, since budgets aren't shared the way categories are.
@Model
final class Budget {
    var id: UUID = UUID()
    var limitAmount: Double = 0
    var workspace: Workspace?
    var category: Category?

    init(
        id: UUID = UUID(),
        workspace: Workspace?,
        category: Category?,
        limitAmount: Double
    ) {
        self.id = id
        self.workspace = workspace
        self.category = category
        self.limitAmount = limitAmount
    }
}
