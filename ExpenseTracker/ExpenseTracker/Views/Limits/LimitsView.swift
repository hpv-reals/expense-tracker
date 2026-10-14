import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LimitsView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query(sort: \RecurringBill.name) private var allRecurringBills: [RecurringBill]
    @Query private var allBudgets: [Budget]
    @Query(sort: \Workspace.name) private var workspaces: [Workspace]
    @AppStorage("selectedWorkspaceIDString") private var selectedWorkspaceIDString: String = ""

    @Environment(\.modelContext) private var modelContext
    @State private var editorTarget: BudgetEditorCard.Target?
    @State private var billEditorTarget: RecurringBillEditorCard.Target?

    @State private var exportDocument = BackupJSONDocument(data: Data())
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupResultMessage: String?

    /// The workspace ("Cá nhân" vs "Doanh nghiệp") currently in effect — see
    /// `WorkspaceSwitcher`. Falls back to the default workspace (and then to
    /// whatever exists) so a not-yet-persisted selection, or a since-deleted
    /// one, never leaves the tab showing nothing.
    private var currentWorkspace: Workspace? {
        workspaces.first(where: { $0.id.uuidString == selectedWorkspaceIDString })
            ?? workspaces.first(where: \.isDefault)
            ?? workspaces.first
    }

    private var workspaceTransactions: [Transaction] {
        allTransactions.filter { $0.workspace?.id == currentWorkspace?.id }
    }

    private var recurringBills: [RecurringBill] {
        allRecurringBills.filter { $0.workspace?.id == currentWorkspace?.id }
    }

    /// Budgets are per-(workspace, category) — the same category can carry
    /// a different limit (or none) in another workspace, so this only ever
    /// looks at the current workspace's rows.
    private var workspaceBudgets: [Budget] {
        allBudgets.filter { $0.workspace?.id == currentWorkspace?.id }
    }

    /// Only expense categories can carry a budget — the rest have nothing to limit.
    private var budgetedCategories: [(category: Category, budget: Budget)] {
        workspaceBudgets.compactMap { budget in
            guard let category = budget.category, category.defaultType == .expense else { return nil }
            return (category, budget)
        }
        .sorted { $0.category.name < $1.category.name }
    }

    private var unbudgetedCategories: [Category] {
        let budgetedIDs = Set(workspaceBudgets.compactMap { $0.category?.id })
        return categories.filter { $0.defaultType == .expense && !budgetedIDs.contains($0.id) }
    }

    /// Recurring bills are always expenses, so only expense categories make sense here.
    private var expenseCategories: [Category] {
        categories.filter { $0.defaultType == .expense }
    }

    private func spentThisMonth(for category: Category) -> Double {
        BudgetChecker.spentThisMonth(for: category, transactions: workspaceTransactions)
    }

    /// Every category (add/edit/delete) lives on its own pushed screen — see
    /// `CategoriesView` — rather than inline here, since with Budgets,
    /// Recurring Bills, and Backup already sharing this tab, the full list
    /// (dozens of categories by default) would make it unreasonably long.
    /// Categories are shared across every workspace, so this count isn't
    /// scoped to `currentWorkspace` the way the sections below are.
    private var categoriesSection: some View {
        Section("Categories") {
            NavigationLink {
                CategoriesView(selectedTab: $selectedTab)
            } label: {
                HStack {
                    Label("Manage Categories", systemImage: "tag.fill")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(categories.count)")
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    /// Same idea as `categoriesSection`, but for the workspaces themselves —
    /// pushed to its own screen (`WorkspacesView`) for the same reason.
    private var workspacesSection: some View {
        Section("Workspaces") {
            NavigationLink {
                WorkspacesView(selectedTab: $selectedTab)
            } label: {
                HStack {
                    Label("Manage Workspaces", systemImage: "person.2.badge.gearshape.fill")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(workspaces.count)")
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    categoriesSection
                    workspacesSection

                    Section("Budgets") {
                        addBudgetDraftRow
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if budgetedCategories.isEmpty {
                            ContentUnavailableView(
                                "No budgets set",
                                systemImage: "gauge.with.dots.needle.67percent",
                                description: Text("Tap + above to set a monthly limit on a category")
                            )
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(budgetedCategories, id: \.category.id) { entry in
                                LimitRow(category: entry.category, limit: entry.budget.limitAmount, spent: spentThisMonth(for: entry.category))
                                    .contentShape(Rectangle())
                                    .onTapGesture { editorTarget = .edit(entry.budget) }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            removeLimit(entry.budget)
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    Section("Recurring Bills") {
                        addRecurringBillDraftRow
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if recurringBills.isEmpty {
                            Text("No recurring bills yet — add iCloud, YouTube, rent, etc.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(recurringBills) { bill in
                                RecurringBillRow(bill: bill)
                                    .contentShape(Rectangle())
                                    .onTapGesture { billEditorTarget = .edit(bill) }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteBill(bill)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    backupSection
                }
                .safeAreaInset(edge: .bottom) {
                    FloatingTabBar.hiddenSpacer(selectedTab: $selectedTab)
                }
                .navigationTitle("Manage")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        WorkspaceSwitcher(workspaces: workspaces, selectedWorkspaceIDString: $selectedWorkspaceIDString)
                    }
                }
                .fileExporter(
                    isPresented: $isExportingBackup,
                    document: exportDocument,
                    contentType: .json,
                    defaultFilename: backupDefaultFilename,
                    onCompletion: handleExportResult
                )
                .fileImporter(
                    isPresented: $isImportingBackup,
                    allowedContentTypes: [.json],
                    onCompletion: handleImportResult
                )
                .alert(
                    "Backup",
                    isPresented: Binding(
                        get: { backupResultMessage != nil },
                        set: { isPresented in if !isPresented { backupResultMessage = nil } }
                    ),
                    presenting: backupResultMessage
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
            }

            if let editorTarget, let currentWorkspace {
                BudgetEditorCard(
                    target: editorTarget,
                    workspace: currentWorkspace,
                    unbudgetedCategories: unbudgetedCategories,
                    onDismiss: { self.editorTarget = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if let billEditorTarget, let currentWorkspace {
                RecurringBillEditorCard(
                    target: billEditorTarget,
                    workspace: currentWorkspace,
                    expenseCategories: expenseCategories,
                    onDismiss: { self.billEditorTarget = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editorTarget)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: billEditorTarget)
    }

    /// A dashed "draft" card pinned to the top of the list — tap the centered +
    /// to add a budget, instead of reaching for a corner toolbar button.
    private var addBudgetDraftRow: some View {
        Button {
            editorTarget = .add
        } label: {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                    Text("Add Budget")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(unbudgetedCategories.isEmpty ? .tertiary : .secondary)
                .padding(.vertical, 14)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.tertiary)
        )
        .disabled(unbudgetedCategories.isEmpty || currentWorkspace == nil)
    }

    /// Same dashed "draft" card style as `addBudgetDraftRow`, for consistency
    /// between the two add flows in this tab.
    private var addRecurringBillDraftRow: some View {
        Button {
            billEditorTarget = .add
        } label: {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 26))
                    Text("Add Bill")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.vertical, 14)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(.tertiary)
        )
    }

    private func removeLimit(_ budget: Budget) {
        modelContext.delete(budget)
        try? modelContext.save()
    }

    private func deleteBill(_ bill: RecurringBill) {
        modelContext.delete(bill)
        try? modelContext.save()
    }

    // MARK: - Backup (export/import as JSON)

    /// Export writes every workspace, category, budget, transaction, and
    /// recurring bill to a single JSON file; import upserts from one by
    /// `id`, so restoring the same file twice (or a backup taken on another
    /// device) never duplicates data — see `BackupManager`.
    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                Label("Export Backup (JSON)", systemImage: "square.and.arrow.up")
            }

            Button {
                isImportingBackup = true
            } label: {
                Label("Import Backup (JSON)", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Export saves every workspace, category, budget, transaction, and recurring bill to a JSON file. Import restores from one — existing records are updated in place, so re-importing the same file is safe.")
        }
    }

    private static let backupFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var backupDefaultFilename: String {
        "expense-tracker-backup-\(Self.backupFilenameFormatter.string(from: Date()))"
    }

    private func exportBackup() {
        do {
            let data = try BackupManager.exportData(context: modelContext)
            exportDocument = BackupJSONDocument(data: data)
            isExportingBackup = true
        } catch {
            backupResultMessage = "Xuất dữ liệu thất bại: \(error.localizedDescription)"
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            backupResultMessage = "Đã xuất file backup thành công."
        case .failure(let error):
            // Cancelling the save sheet also surfaces here as an error; don't
            // scare the user with an alert over a plain cancel.
            let nsError = error as NSError
            guard nsError.code != NSUserCancelledError else { return }
            backupResultMessage = "Xuất dữ liệu thất bại: \(error.localizedDescription)"
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.code != NSUserCancelledError else { return }
            backupResultMessage = "Không thể mở file: \(error.localizedDescription)"
        case .success(let url):
            let needsSecurityScope = url.startAccessingSecurityScopedResource()
            defer { if needsSecurityScope { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let summary = try BackupManager.importData(data, context: modelContext, fallbackWorkspace: currentWorkspace)
                backupResultMessage = importSummaryText(summary)
            } catch {
                backupResultMessage = "Import thất bại: \(error.localizedDescription)"
            }
        }
    }

    private func importSummaryText(_ summary: BackupManager.ImportSummary) -> String {
        guard !summary.isEmpty else {
            return "File backup không có dữ liệu mới."
        }
        var lines: [String] = []
        if summary.importedWorkspaces > 0 || summary.updatedWorkspaces > 0 {
            lines.append("Workspace: thêm \(summary.importedWorkspaces), cập nhật \(summary.updatedWorkspaces).")
        }
        if summary.importedCategories > 0 || summary.updatedCategories > 0 {
            lines.append("Danh mục: thêm \(summary.importedCategories), cập nhật \(summary.updatedCategories).")
        }
        if summary.importedBudgets > 0 || summary.updatedBudgets > 0 {
            lines.append("Ngân sách: thêm \(summary.importedBudgets), cập nhật \(summary.updatedBudgets).")
        }
        if summary.importedTransactions > 0 || summary.updatedTransactions > 0 {
            lines.append("Giao dịch: thêm \(summary.importedTransactions), cập nhật \(summary.updatedTransactions).")
        }
        if summary.importedRecurringBills > 0 || summary.updatedRecurringBills > 0 {
            lines.append("Hóa đơn định kỳ: thêm \(summary.importedRecurringBills), cập nhật \(summary.updatedRecurringBills).")
        }
        return lines.joined(separator: "\n")
    }
}
