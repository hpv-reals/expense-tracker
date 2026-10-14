import SwiftUI

/// A row in `CategoriesView`: icon, name, money-flow type, and — only once
/// the category has been used — a small lock badge with its transaction
/// count, explaining at a glance why swiping it no longer offers Delete.
struct CategoryManagementRow: View {
    let category: Category

    private var tint: Color { Color(hex: category.colorHex) }
    private var transactionCount: Int { category.transactions?.count ?? 0 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: category.iconName)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(category.defaultType.shortLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if transactionCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                    Text("\(transactionCount)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}
