import SwiftUI
import SwiftData

struct LimitsView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allTransactions: [Transaction]

    @Environment(\.modelContext) private var modelContext
    @State private var editorTarget: BudgetEditorCard.Target?
    @StateObject private var keyboard = KeyboardVisibility()

    /// Only expense categories can carry a budget — the rest have nothing to limit.
    private var budgetedCategories: [Category] {
        categories.filter { $0.defaultType == .expense && $0.limitAmount != nil }
    }

    private var unbudgetedCategories: [Category] {
        categories.filter { $0.defaultType == .expense && $0.limitAmount == nil }
    }

    private func spentThisMonth(for category: Category) -> Double {
        BudgetChecker.spentThisMonth(for: category, transactions: allTransactions)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    Section {
                        addBudgetDraftRow
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

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
                .safeAreaInset(edge: .bottom) {
                    FloatingTabBar(selectedTab: $selectedTab)
                        .hidesWhileKeyboardVisible(keyboard)
                }
                .navigationTitle("Limits")
            }

            if let editorTarget {
                BudgetEditorCard(
                    target: editorTarget,
                    unbudgetedCategories: unbudgetedCategories,
                    onDismiss: { self.editorTarget = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editorTarget)
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

    private func removeLimit(_ category: Category) {
        category.limitAmount = nil
        try? modelContext.save()
    }
}
