import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Exports every `Workspace`, `Category`, `Budget`, `Transaction`, and
/// `RecurringBill` to a single JSON file, and restores from one. Import is
/// an upsert keyed by `id`: a record whose `id` already exists in the store
/// is updated in place: a new one is inserted — so re-importing the same
/// file (or an older backup on top of a newer store) never creates
/// duplicates, and syncing the same backup across devices converges instead
/// of piling up copies.
enum BackupManager {
    struct ImportSummary {
        var importedWorkspaces = 0
        var updatedWorkspaces = 0
        var importedCategories = 0
        var updatedCategories = 0
        var importedBudgets = 0
        var updatedBudgets = 0
        var importedTransactions = 0
        var updatedTransactions = 0
        var importedRecurringBills = 0
        var updatedRecurringBills = 0

        var isEmpty: Bool {
            importedWorkspaces == 0 && updatedWorkspaces == 0
                && importedCategories == 0 && updatedCategories == 0
                && importedBudgets == 0 && updatedBudgets == 0
                && importedTransactions == 0 && updatedTransactions == 0
                && importedRecurringBills == 0 && updatedRecurringBills == 0
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @MainActor
    static func exportData(context: ModelContext) throws -> Data {
        let workspaces = try context.fetch(FetchDescriptor<Workspace>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let bills = try context.fetch(FetchDescriptor<RecurringBill>())

        let backup = Backup(
            exportedAt: Date(),
            workspaces: workspaces.map {
                BackupWorkspace(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex, isDefault: $0.isDefault)
            },
            categories: categories.map {
                BackupCategory(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex, defaultType: $0.defaultType)
            },
            budgets: budgets.map {
                BackupBudget(id: $0.id, workspaceID: $0.workspace?.id, categoryID: $0.category?.id, limitAmount: $0.limitAmount)
            },
            transactions: transactions.map {
                BackupTransaction(
                    id: $0.id,
                    amount: $0.amount,
                    date: $0.date,
                    note: $0.note,
                    type: $0.type,
                    categoryID: $0.category?.id,
                    workspaceID: $0.workspace?.id,
                    recipientName: $0.recipientName,
                    sourceName: $0.sourceName,
                    destinationAccount: $0.destinationAccount,
                    isSettled: $0.isSettled
                )
            },
            recurringBills: bills.map {
                BackupRecurringBill(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.amount,
                    intervalMonths: $0.intervalMonths,
                    anchorDate: $0.anchorDate,
                    cycleCount: $0.cycleCount,
                    nextDueDate: $0.nextDueDate,
                    isActive: $0.isActive,
                    note: $0.note,
                    categoryID: $0.category?.id,
                    workspaceID: $0.workspace?.id
                )
            }
        )
        return try encoder.encode(backup)
    }

    /// - Parameter fallbackWorkspace: where a transaction/bill with no
    ///   `workspaceID` lands — only ever needed for a backup taken before
    ///   workspaces existed (schema version 1).
    @MainActor
    static func importData(_ data: Data, context: ModelContext, fallbackWorkspace: Workspace?) throws -> ImportSummary {
        let backup = try decoder.decode(Backup.self, from: data)
        var summary = ImportSummary()

        // Workspaces and categories are imported first (and indexed by id)
        // so budgets/transactions/bills below can resolve their foreign keys
        // to a live object in the same pass, whether that object already
        // existed or was just created from this same file.
        var workspacesByID: [UUID: Workspace] = [:]
        for existing in try context.fetch(FetchDescriptor<Workspace>()) {
            workspacesByID[existing.id] = existing
        }
        for dto in backup.workspaces {
            if let existing = workspacesByID[dto.id] {
                existing.name = dto.name
                existing.iconName = dto.iconName
                existing.colorHex = dto.colorHex
                existing.isDefault = dto.isDefault
                summary.updatedWorkspaces += 1
            } else {
                let created = Workspace(id: dto.id, name: dto.name, iconName: dto.iconName, colorHex: dto.colorHex, isDefault: dto.isDefault)
                context.insert(created)
                workspacesByID[dto.id] = created
                summary.importedWorkspaces += 1
            }
        }

        var categoriesByID: [UUID: Category] = [:]
        for existing in try context.fetch(FetchDescriptor<Category>()) {
            categoriesByID[existing.id] = existing
        }
        for dto in backup.categories {
            if let existing = categoriesByID[dto.id] {
                existing.name = dto.name
                existing.iconName = dto.iconName
                existing.colorHex = dto.colorHex
                existing.defaultType = dto.defaultType
                summary.updatedCategories += 1
            } else {
                let created = Category(id: dto.id, name: dto.name, iconName: dto.iconName, colorHex: dto.colorHex, defaultType: dto.defaultType)
                context.insert(created)
                categoriesByID[dto.id] = created
                summary.importedCategories += 1
            }
        }

        var budgetsByID: [UUID: Budget] = [:]
        for existing in try context.fetch(FetchDescriptor<Budget>()) {
            budgetsByID[existing.id] = existing
        }
        for dto in backup.budgets {
            let workspace = dto.workspaceID.flatMap { workspacesByID[$0] } ?? fallbackWorkspace
            let category = dto.categoryID.flatMap { categoriesByID[$0] }
            if let existing = budgetsByID[dto.id] {
                existing.workspace = workspace
                existing.category = category
                existing.limitAmount = dto.limitAmount
                summary.updatedBudgets += 1
            } else {
                let created = Budget(id: dto.id, workspace: workspace, category: category, limitAmount: dto.limitAmount)
                context.insert(created)
                budgetsByID[dto.id] = created
                summary.importedBudgets += 1
            }
        }

        var transactionsByID: [UUID: Transaction] = [:]
        for existing in try context.fetch(FetchDescriptor<Transaction>()) {
            transactionsByID[existing.id] = existing
        }
        for dto in backup.transactions {
            let category = dto.categoryID.flatMap { categoriesByID[$0] }
            let workspace = dto.workspaceID.flatMap { workspacesByID[$0] } ?? fallbackWorkspace
            if let existing = transactionsByID[dto.id] {
                existing.amount = dto.amount
                existing.date = dto.date
                existing.note = dto.note
                existing.type = dto.type
                existing.category = category
                existing.workspace = workspace
                existing.recipientName = dto.recipientName
                existing.sourceName = dto.sourceName
                existing.destinationAccount = dto.destinationAccount
                existing.isSettled = dto.isSettled ?? true
                summary.updatedTransactions += 1
            } else {
                let created = Transaction(
                    id: dto.id,
                    amount: dto.amount,
                    date: dto.date,
                    note: dto.note,
                    type: dto.type,
                    category: category,
                    workspace: workspace,
                    recipientName: dto.recipientName,
                    sourceName: dto.sourceName,
                    destinationAccount: dto.destinationAccount,
                    isSettled: dto.isSettled ?? true
                )
                context.insert(created)
                transactionsByID[dto.id] = created
                summary.importedTransactions += 1
            }
        }

        var billsByID: [UUID: RecurringBill] = [:]
        for existing in try context.fetch(FetchDescriptor<RecurringBill>()) {
            billsByID[existing.id] = existing
        }
        for dto in backup.recurringBills {
            let category = dto.categoryID.flatMap { categoriesByID[$0] }
            let workspace = dto.workspaceID.flatMap { workspacesByID[$0] } ?? fallbackWorkspace
            if let existing = billsByID[dto.id] {
                existing.name = dto.name
                existing.amount = dto.amount
                existing.intervalMonths = dto.intervalMonths
                existing.anchorDate = dto.anchorDate
                existing.cycleCount = dto.cycleCount
                existing.nextDueDate = dto.nextDueDate
                existing.isActive = dto.isActive
                existing.note = dto.note
                existing.category = category
                existing.workspace = workspace
                summary.updatedRecurringBills += 1
            } else {
                let created = RecurringBill(
                    id: dto.id,
                    name: dto.name,
                    amount: dto.amount,
                    intervalMonths: dto.intervalMonths,
                    anchorDate: dto.anchorDate,
                    cycleCount: dto.cycleCount,
                    nextDueDate: dto.nextDueDate,
                    isActive: dto.isActive,
                    note: dto.note,
                    category: category,
                    workspace: workspace
                )
                context.insert(created)
                billsByID[dto.id] = created
                summary.importedRecurringBills += 1
            }
        }

        try context.save()
        return summary
    }
}

/// Wraps the exported JSON `Data` so `.fileExporter` can hand it to the
/// system save/share sheet.
struct BackupJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
