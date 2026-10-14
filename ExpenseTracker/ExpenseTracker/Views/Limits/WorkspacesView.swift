import SwiftUI
import SwiftData

/// Full workspace list — pushed from the "Manage" tab (see `LimitsView`),
/// the same way `CategoriesView` is: a plain `NavigationLink` push, so the
/// back button top-left and the interactive edge-swipe-back gesture both
/// come for free from `NavigationStack`.
///
/// A workspace can only be deleted once it's non-default and has no data at
/// all (no transactions, recurring bills, or budgets) — the default
/// workspace is never offered for deletion, so the app always has somewhere
/// to fall back to.
struct WorkspacesView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Workspace.name) private var workspaces: [Workspace]
    @Environment(\.modelContext) private var modelContext
    @State private var editorTarget: WorkspaceEditorCard.Target?

    var body: some View {
        ZStack {
            List {
                addDraftRow
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(workspaces) { workspace in
                    WorkspaceManagementRow(workspace: workspace)
                        .contentShape(Rectangle())
                        .onTapGesture { editorTarget = .edit(workspace) }
                        .swipeActions(edge: .trailing) {
                            if canDelete(workspace) {
                                Button(role: .destructive) {
                                    delete(workspace)
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
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.inline)

            if let editorTarget {
                WorkspaceEditorCard(target: editorTarget, onDismiss: { self.editorTarget = nil })
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editorTarget)
    }

    /// Same dashed "draft" card style as every other add row in the Manage tab.
    private var addDraftRow: some View {
        Button {
            editorTarget = .add
        } label: {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                    Text("Add Workspace")
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

    private func canDelete(_ workspace: Workspace) -> Bool {
        guard !workspace.isDefault else { return false }
        return (workspace.transactions?.isEmpty ?? true)
            && (workspace.recurringBills?.isEmpty ?? true)
            && (workspace.budgets?.isEmpty ?? true)
    }

    private func delete(_ workspace: Workspace) {
        guard canDelete(workspace) else { return }
        modelContext.delete(workspace)
        try? modelContext.save()
    }
}
