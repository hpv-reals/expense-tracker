import SwiftUI
import SwiftData

struct LimitsView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allTransactions: [Transaction]
    @Query(sort: \RecurringBill.name) private var recurringBills: [RecurringBill]

    @Environment(\.modelContext) private var modelContext
    @State private var editorTarget: BudgetEditorCard.Target?
    @State private var billEditorTarget: RecurringBillEditorCard.Target?

    /// Only expense categories can carry a budget — the rest have nothing to limit.
    private var budgetedCategories: [Category] {
        categories.filter { $0.defaultType == .expense && $0.limitAmount != nil }
    }

    private var unbudgetedCategories: [Category] {
        categories.filter { $0.defaultType == .expense && $0.limitAmount == nil }
    }

    /// Recurring bills are always expenses, so only expense categories make sense here.
    private var expenseCategories: [Category] {
        categories.filter { $0.defaultType == .expense }
    }

    private func spentThisMonth(for category: Category) -> Double {
        BudgetChecker.spentThisMonth(for: category, transactions: allTransactions)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
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
                            ForEach(budgetedCategories) { category in
                                LimitRow(category: category, spent: spentThisMonth(for: category))
                                    .contentShape(Rectangle())
                                    .onTapGesture { editorTarget = .edit(category) }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            removeLimit(category)
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
                }
                .safeAreaInset(edge: .bottom) {
                    FloatingTabBar.hiddenSpacer(selectedTab: $selectedTab)
                }
                .navigationTitle("Manage")
            }

            if let editorTarget {
                BudgetEditorCard(
                    target: editorTarget,
                    unbudgetedCategories: unbudgetedCategories,
                    onDismiss: { self.editorTarget = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            if let billEditorTarget {
                RecurringBillEditorCard(
                    target: billEditorTarget,
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
        .disabled(unbudgetedCategories.isEmpty)
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

    private func removeLimit(_ category: Category) {
        category.limitAmount = nil
        try? modelContext.save()
    }

    private func deleteBill(_ bill: RecurringBill) {
        modelContext.delete(bill)
        try? modelContext.save()
    }
}
