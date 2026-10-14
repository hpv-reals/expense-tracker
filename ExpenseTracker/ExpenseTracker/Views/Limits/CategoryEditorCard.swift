import SwiftUI
import SwiftData

/// Centered card for adding or editing a category — name, money-flow type,
/// icon, and color. Mirrors `BudgetEditorCard`/`RecurringBillEditorCard`'s
/// layout so every editor opened from the Manage tab feels like the same
/// family of control.
///
/// Deleting is only offered when the category has no transaction history —
/// deleting one that does would cascade-delete every transaction in it (see
/// `Category.transactions`'s `.cascade` delete rule), silently erasing real
/// data. Everything else about an existing category (name, type, icon,
/// color) stays freely editable, since none of that touches a transaction.
struct CategoryEditorCard: View {
    enum Target: Identifiable, Equatable {
        case add
        case edit(Category)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let category): return category.id.uuidString
            }
        }
    }

    let target: Target
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var type: TransactionType = .expense
    @State private var iconName: String = CategoryStylePalette.icons[0]
    @State private var colorHex: String = CategoryStylePalette.colors[0]

    private var existingCategory: Category? {
        if case .edit(let category) = target { return category }
        return nil
    }

    /// Whether this category has ever been used on a transaction — the sole
    /// gate on whether it may be deleted at all.
    private var canDelete: Bool {
        existingCategory?.transactions?.isEmpty ?? false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The icon/color swatch rows always include every curated option, plus
    /// whatever value the category already has (even if it isn't one of the
    /// curated choices) so an existing custom value still shows as selected
    /// instead of silently falling off the visible list.
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
            Text(existingCategory == nil ? "Add Category" : "Edit Category")
                .font(.headline)

            preview

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            typePicker

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

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Type", selection: $type) {
                ForEach(TransactionType.allCases) { type in
                    Text(type.shortLabel).tag(type)
                }
            }
            .pickerStyle(.segmented)
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

            if existingCategory != nil {
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
                    Text("This category already has transactions, so it can't be deleted — only edited.")
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
        guard let existingCategory else { return }
        name = existingCategory.name
        type = existingCategory.defaultType
        iconName = existingCategory.iconName
        colorHex = existingCategory.colorHex
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingCategory {
            existingCategory.name = trimmedName
            existingCategory.defaultType = type
            existingCategory.iconName = iconName
            existingCategory.colorHex = colorHex
        } else {
            let category = Category(
                name: trimmedName,
                iconName: iconName,
                colorHex: colorHex,
                defaultType: type
            )
            modelContext.insert(category)
        }

        try? modelContext.save()
        onDismiss()
    }

    private func delete() {
        guard let existingCategory, canDelete else { return }
        modelContext.delete(existingCategory)
        try? modelContext.save()
        onDismiss()
    }
}
