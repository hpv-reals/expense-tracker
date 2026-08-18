import SwiftUI

/// A round icon + label used to pick a category, both in the Home input area
/// and in the edit sheet.
struct CategoryChip: View {
    let category: Category
    let isSelected: Bool

    private var tint: Color { Color(hex: category.colorHex) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isSelected ? tint : tint.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: category.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
            }
            .overlay(
                Circle()
                    .stroke(tint, lineWidth: isSelected ? 2 : 0)
                    .frame(width: 56, height: 56)
            )

            Text(category.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 64)
        }
        .contentShape(Rectangle())
    }
}
