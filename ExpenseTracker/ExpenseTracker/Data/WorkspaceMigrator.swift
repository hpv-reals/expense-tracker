import Foundation
import SwiftData

/// One-time (per store) setup for the workspace feature: makes sure the two
/// starter workspaces exist, folds any pre-workspace data into the default
/// one, and migrates the old per-category `limitAmount` into `Budget` rows.
/// Safe to call on every launch — every step below is a no-op once it's
/// already happened.
enum WorkspaceMigrator {
    @MainActor
    static func migrateIfNeeded(context: ModelContext) {
        let defaultWorkspace = ensureWorkspaces(context: context)
        migrateLegacyBudgets(defaultWorkspace: defaultWorkspace, context: context)
        backfillWorkspace(defaultWorkspace: defaultWorkspace, context: context)
        try? context.save()
    }

    /// Finds the existing default workspace, or — only on the very first
    /// launch this store has ever seen workspaces — creates both starter
    /// workspaces ("Cá nhân" as default, "Doanh nghiệp" alongside it). Safe
    /// to call repeatedly: a default workspace can never be deleted (see
    /// `WorkspacesView`), so once created, this branch never runs again.
    @MainActor
    private static func ensureWorkspaces(context: ModelContext) -> Workspace {
        let existing = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        if let existingDefault = existing.first(where: { $0.isDefault }) {
            return existingDefault
        }

        let personal = Workspace(name: "Cá nhân", iconName: "person.fill", colorHex: "#007AFF", isDefault: true)
        let business = Workspace(name: "Doanh nghiệp", iconName: "briefcase.fill", colorHex: "#5856D6", isDefault: false)
        context.insert(personal)
        context.insert(business)
        return personal
    }

    /// Every category's old `limitAmount` becomes a `Budget` under the
    /// default workspace, then is cleared so this never re-runs for it.
    @MainActor
    private static func migrateLegacyBudgets(defaultWorkspace: Workspace, context: ModelContext) {
        guard let categories = try? context.fetch(FetchDescriptor<Category>()) else { return }
        for category in categories {
            guard let legacyLimit = category.limitAmount else { continue }
            let alreadyMigrated = (category.budgets ?? []).contains { $0.workspace?.id == defaultWorkspace.id }
            if !alreadyMigrated {
                context.insert(Budget(workspace: defaultWorkspace, category: category, limitAmount: legacyLimit))
            }
            category.limitAmount = nil
        }
    }

    /// Any transaction/bill created before workspaces existed (or restored
    /// from a pre-workspace backup) gets attached to the default workspace.
    @MainActor
    private static func backfillWorkspace(defaultWorkspace: Workspace, context: ModelContext) {
        if let transactions = try? context.fetch(FetchDescriptor<Transaction>()) {
            for transaction in transactions where transaction.workspace == nil {
                transaction.workspace = defaultWorkspace
            }
        }
        if let bills = try? context.fetch(FetchDescriptor<RecurringBill>()) {
            for bill in bills where bill.workspace == nil {
                bill.workspace = defaultWorkspace
            }
        }
    }
}
