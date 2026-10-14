import SwiftUI
import SwiftData

/// Centered card for adding or editing a workspace — name, icon, and color.
/// Mirrors `CategoryEditorCard`'s layout (name field, then icon/color swatch
/// rows) so every editor opened from the Manage tab feels like the same
/// family of control.
///
/// Deleting is only offered for a non-default workspace with no data in it
/// at all (no transactions, recurring bills, or budgets) — the default
/// workspace can never be deleted, so the app always has somewhere to fall
/// back to (see `WorkspaceMigrator`).
struct WorkspaceEditorCard: View {
    enum Target: Identifiable, Equatable {
        case add
        case edit(Workspace)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let workspace): return workspace.id.uuidString
            }
        }
    }

    let target: Target
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var iconName: String = "briefcase.fill"
    @State private var colorHex: String = "#5856D6"

    private var existingWorkspace: Workspace? {
        if case .edit(let workspace) = target { return workspace }
        return nil
    }

    /// Only a non-default workspace with no transactions, recurring bills,
    /// or budgets at all is safe to delete outright.
    private var canDelete: Bool {
        guard let existingWorkspace, !existingWorkspace.isDefault else { return false }
        return (existingWorkspace.transactions?.isEmpty ?? true)
            && (existingWorkspace.recurringBills?.isEmpty ?? true)
            && (existingWorkspace.budgets?.isEmpty ?? true)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var displayIcons: [String] {
        CategoryStylePalette.icons.contains(iconName)
            ? CategoryStylePalette.icons
            : [iconName] + CategoryStylePalette.icons
    }

    private var displayColors: [String] {
        CategoryStylePalette.colors.contains(colorHex)
            ? CategoryStylePalette.colors
            : [colorHex] + CategoryStylePalette.colors
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            card
        }
        .onAppear(perform: loadExistingValues)
        .dismissKeyboardOnTap()
    }

    private var card: some View {
        VStack(spacing: 16) {
            Text(existingWorkspace == nil ? "Add Workspace" : "Edit Workspace")
                .font(.headline)

            preview

            TextField("Name (e.g. Doanh nghiệp)", text: $name)
                .textFieldStyle(.roundedBorder)

            paletteSection(title: "Icon") { iconRow }
            paletteSection(title: "Color") { colorRow }

            actions
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(.horizontal, 24)
    }

    private var preview: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.16))
                .frame(width: 56, height: 56)
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
        }
    }

    @ViewBuilder
    private func paletteSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var iconRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(displayIcons, id: \.self, content: iconSwatch)
            }
            .padding(.vertical, 2)
        }
    }

    private var colorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(displayColors, id: \.self, content: colorSwatch)
            }
            .padding(.vertical, 2)
        }
    }

    private func iconSwatch(_ icon: String) -> some View {
        let isSelected = icon == iconName
        return Button {
            iconName = icon
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? .white : Color(hex: colorHex))
            }
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(_ hex: String) -> some View {
        let isSelected = hex == colorHex
        return Button {
            colorHex = hex
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 32, height: 32)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var actions: some View {
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

            if existingWorkspace != nil {
                if canDelete {
                    HStack(spacing: 12) {
                        Button(action: delete) {
                            Text("Delete")
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
                    Text(existingWorkspace?.isDefault == true
                        ? "This is the default workspace, so it can't be deleted — only edited."
                        : "This workspace already has data, so it can't be deleted — only edited.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    cancelButton
                }
            } else {
                cancelButton
            }
        }
    }

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

    private func loadExistingValues() {
        guard let existingWorkspace else { return }
        name = existingWorkspace.name
        iconName = existingWorkspace.iconName
        colorHex = existingWorkspace.colorHex
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingWorkspace {
            existingWorkspace.name = trimmedName
            existingWorkspace.iconName = iconName
            existingWorkspace.colorHex = colorHex
        } else {
            let workspace = Workspace(name: trimmedName, iconName: iconName, colorHex: colorHex)
            modelContext.insert(workspace)
        }

        try? modelContext.save()
        onDismiss()
    }

    private func delete() {
        guard let existingWorkspace, canDelete else { return }
        modelContext.delete(existingWorkspace)
        try? modelContext.save()
        onDismiss()
    }
}
