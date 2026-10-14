import SwiftUI
import SwiftData

/// Full category list — pushed from the "Manage" tab (see `LimitsView`)
/// rather than folded inline there, since with Budgets, Recurring Bills, and
/// Backup already sharing that tab, every category (there are dozens by
/// default) would make it unreasonably long. A plain `NavigationLink` push,
/// so the back button top-left and the interactive edge-swipe-back gesture
/// both come for free from `NavigationStack` — nothing custom needed.
///
/// A category can only be deleted once it has no transaction history —
/// deleting one that does would cascade-delete every transaction in it (see
/// `Category.transactions`). Everything else stays freely editable.
struct CategoriesView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Category.name) private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    @State private var editorTarget: CategoryEditorCard.Target?

    var body: some View {
        ZStack {
            List {
                addDraftRow
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(categories) { category in
                    CategoryManagementRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture { editorTarget = .edit(category) }
                        .swipeActions(edge: .trailing) {
                            if canDelete(category) {
                                Button(role: .destructive) {
                                    delete(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FloatingTabBar.hiddenSpacer(selectedTab: $selectedTab)
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)

            if let editorTarget {
                CategoryEditorCard(target: editorTarget, onDismiss: { self.editorTarget = nil })
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editorTarget)
    }

    /// Same dashed "draft" card style as the add rows in `LimitsView`, for
    /// consistency between every add flow in the Manage tab.
    private var addDraftRow: some View {
        Button {
            editorTarget = .add
        } label: {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                    Text("Add Category")
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

    private func canDelete(_ category: Category) -> Bool {
        category.transactions?.isEmpty ?? true
    }

    private func delete(_ category: Category) {
        guard canDelete(category) else { return }
        modelContext.delete(category)
        try? modelContext.save()
    }
}
