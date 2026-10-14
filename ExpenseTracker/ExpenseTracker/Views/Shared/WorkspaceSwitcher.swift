import SwiftUI

/// Leading toolbar control on every tab (Home/Reports/Manage) for switching
/// which workspace's data is currently shown. Reads/writes the same
/// `@AppStorage` key every tab holds its own copy of, so switching in one
/// tab immediately updates the other two — all three stay mounted at once
/// (see `RootTabView`), so there's no separate state to keep in sync.
struct WorkspaceSwitcher: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceIDString: String

    private var current: Workspace? {
        workspaces.first(where: { $0.id.uuidString == selectedWorkspaceIDString })
            ?? workspaces.first(where: \.isDefault)
            ?? workspaces.first
    }

    var body: some View {
        Menu {
            ForEach(workspaces) { workspace in
                Button {
                    selectedWorkspaceIDString = workspace.id.uuidString
                } label: {
                    HStack {
                        Image(systemName: workspace.iconName)
                        Text(workspace.name)
                        if workspace.id == current?.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: current?.iconName ?? "person.fill")
                Text(current?.name ?? "Workspace")
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(hex: current?.colorHex ?? "#007AFF"))
        }
    }
}
