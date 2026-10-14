import SwiftUI

/// A row in `WorkspacesView`: icon, name, a "Default" badge for the one
/// workspace that can never be deleted, and — once a workspace has any data
/// — a small lock badge explaining why swiping it no longer offers Delete.
struct WorkspaceManagementRow: View {
    let workspace: Workspace

    private var tint: Color { Color(hex: workspace.colorHex) }

    private var dataCount: Int {
        (workspace.transactions?.count ?? 0)
            + (workspace.recurringBills?.count ?? 0)
            + (workspace.budgets?.count ?? 0)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: workspace.iconName)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if workspace.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !workspace.isDefault && dataCount > 0 {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
