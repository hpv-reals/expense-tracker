import Foundation

/// Codable mirror of the SwiftData models, used only for JSON backup/restore.
/// Kept separate from `@Model` classes because `Codable` conformance on a
/// `@Model` type fights with SwiftData's own storage; these DTOs carry
/// relationships as plain `UUID` foreign keys (`categoryID`, `workspaceID`)
/// instead of object references, which is also what makes the JSON portable
/// across devices/stores.
struct BackupWorkspace: Codable {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isDefault: Bool
}

struct BackupCategory: Codable {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var defaultType: TransactionType
}

/// A monthly limit on one category, scoped to one workspace — see `Budget`.
struct BackupBudget: Codable {
    var id: UUID
    var workspaceID: UUID?
    var categoryID: UUID?
    var limitAmount: Double
}

struct BackupTransaction: Codable {
    var id: UUID
    var amount: Double
    var date: Date
    var note: String?
    var type: TransactionType
    /// `nil` if the transaction had no category (or the category couldn't be
    /// resolved at export time).
    var categoryID: UUID?
    /// Which workspace this transaction belongs to — `nil` only for a
    /// backup taken before workspaces existed; import falls back to
    /// whichever workspace is current at the time (see `BackupManager`).
    var workspaceID: UUID?
    /// Added after schema v2; absent in older files, so all optional.
    var recipientName: String?
    var sourceName: String?
    var destinationAccount: String?
    var isSettled: Bool?
}

struct BackupRecurringBill: Codable {
    var id: UUID
    var name: String
    var amount: Double
    var intervalMonths: Int
    var anchorDate: Date
    var cycleCount: Int
    var nextDueDate: Date
    var isActive: Bool
    var note: String?
    var categoryID: UUID?
    var workspaceID: UUID?
}

/// Top-level shape of an exported `.json` backup file.
struct Backup: Codable {
    /// Bumped whenever the shape below changes in a way `BackupManager`
    /// needs to branch on. Version 1 predates `workspaces`/`budgets` (and
    /// carried the since-removed `limitAmount` directly on `categories`) —
    /// decoding tolerates a v1 file missing those newer fields entirely.
    var schemaVersion: Int = 2
    var exportedAt: Date
    var workspaces: [BackupWorkspace]
    var categories: [BackupCategory]
    var budgets: [BackupBudget]
    var transactions: [BackupTransaction]
    var recurringBills: [BackupRecurringBill]

    init(
        schemaVersion: Int = 2,
        exportedAt: Date,
        workspaces: [BackupWorkspace],
        categories: [BackupCategory],
        budgets: [BackupBudget],
        transactions: [BackupTransaction],
        recurringBills: [BackupRecurringBill]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.workspaces = workspaces
        self.categories = categories
        self.budgets = budgets
        self.transactions = transactions
        self.recurringBills = recurringBills
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        // Absent entirely in a v1 file rather than merely empty, so these two
        // need an explicit fallback — `decodeIfPresent` alone still throws if
        // the key is missing outright, only `try?` truly tolerates that.
        workspaces = (try? container.decode([BackupWorkspace].self, forKey: .workspaces)) ?? []
        budgets = (try? container.decode([BackupBudget].self, forKey: .budgets)) ?? []
        categories = try container.decode([BackupCategory].self, forKey: .categories)
        transactions = try container.decode([BackupTransaction].self, forKey: .transactions)
        recurringBills = try container.decode([BackupRecurringBill].self, forKey: .recurringBills)
    }
}
