import SwiftUI

struct CategorySpend: Identifiable {
    let category: Category
    let total: Double
    var id: UUID { category.id }
}

struct CategorySpendRow: View {
    let item: CategorySpend
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: item.category.colorHex).opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: item.category.colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text("\(Int((percentage * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.total.formattedCurrency)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .contentShape(Rectangle())
    }
}
