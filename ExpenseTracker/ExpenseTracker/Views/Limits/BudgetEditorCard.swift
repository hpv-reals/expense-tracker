import SwiftUI
import SwiftData

/// A small, center-screen card for adding or editing a category's budget limit.
///
/// Deliberately a compact centered card rather than a full-height bottom sheet:
/// every control — category picker, amount field, Save/Cancel/Remove — sits
/// close together in the middle of the screen instead of being spread across
/// far corners (top-right Save, trailing-aligned fields), which forced an
/// awkward thumb reach.
struct BudgetEditorCard: View {
    enum Target: Identifiable, Equatable {
        case add
        case edit(Budget)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let budget): return budget.id.uuidString
            }
        }
    }

    let target: Target
    /// Which ledger a newly-created budget is attached to — an existing
    /// budget being edited already has its own workspace and doesn't need this.
    let workspace: Workspace
    let unbudgetedCategories: [Category]
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: Category?
    @State private var amount: Double = 0

    private var existingBudget: Budget? {
        if case .edit(let budget) = target { return budget }
        return nil
    }

    private var existingCategory: Category? { existingBudget?.category }

    private var targetCategory: Category? { existingCategory ?? selectedCategory }
    private var canSave: Bool { targetCategory != nil && amount > 0 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            card
        }
        .onAppear {
            if let existingBudget {
                amount = existingBudget.limitAmount
            }
        }
        .dismissKeyboardOnTap()
    }

    private var card: some View {
        VStack(spacing: 16) {
            Text(existingCategory == nil ? "Add Budget" : "Edit Budget")
                .font(.headline)

            categorySection

            CurrencyAmountField(amount: $amount, font: .system(size: 34, weight: .bold, design: .rounded))

            VStack(spacing: 12) {
                Button(action: save) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSave)

                // Secondary actions are pill buttons of matching size/weight so they
                // read as a deliberate row rather than a stack of cramped text links.
                if existingCategory != nil {
                    HStack(spacing: 12) {
                        Button(action: removeLimit) {
                            Text("Remove Limit")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        cancelButton
                    }
                } else {
                    cancelButton
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(.horizontal, 24)
    }

    /// Styled to match "Remove Limit" (same pill size, padding, and weight) so the two
    /// sit as a symmetric, equally-tappable pair instead of one looking like an afterthought.
    private var cancelButton: some View {
        Button(action: onDismiss) {
            Text("Cancel")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        if let category = existingCategory {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex).opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: category.iconName)
                        .foregroundStyle(Color(hex: category.colorHex))
                }
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
        } else if unbudgetedCategories.isEmpty {
            Text("Every category already has a budget.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            CategorySelector(categories: unbudgetedCategories, selection: $selectedCategory)
        }
    }

    private func save() {
        guard let category = targetCategory, amount > 0 else { return }
        if let existingBudget {
            existingBudget.limitAmount = amount
        } else {
            modelContext.insert(Budget(workspace: workspace, category: category, limitAmount: amount))
        }
        try? modelContext.save()
        onDismiss()
    }

    private func removeLimit() {
        guard let existingBudget else { return }
        modelContext.delete(existingBudget)
        try? modelContext.save()
        onDismiss()
    }
}
