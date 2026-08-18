import SwiftUI

/// The trailing slot in a category row: a chip-styled button that opens a native
/// menu ("combobox") listing every category that didn't fit in the pinned
/// quick-access chips — picking from a dropdown list beats side-scrolling to find one.
struct MoreCategoryPicker: View {
    let categories: [Category]
    @Binding var selection: Category?

    private var isActive: Bool {
        categories.contains { $0.id == selection?.id }
    }

    private var tint: Color {
        isActive ? Color(hex: selection?.colorHex ?? "#8E8E93") : .secondary
    }

    var body: some View {
        Menu {
            ForEach(categories) { category in
                Button {
                    selection = category
                } label: {
                    Label(category.name, systemImage: category.iconName)
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? tint : tint.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: isActive ? (selection?.iconName ?? "ellipsis") : "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isActive ? .white : tint)
                }
                .overlay(
                    Circle()
                        .stroke(tint, lineWidth: isActive ? 2 : 0)
                        .frame(width: 56, height: 56)
                )

                Text(isActive ? (selection?.name ?? "More") : "More")
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .frame(width: 64)
            }
            .contentShape(Rectangle())
        }
    }
}
