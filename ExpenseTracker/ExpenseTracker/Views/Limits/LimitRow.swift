import SwiftUI

struct LimitRow: View {
    let category: Category
    let spent: Double

    private var limit: Double { category.limitAmount ?? 0 }
    private var progress: Double { limit > 0 ? min(spent / limit, 1.0) : 0 }
    private var isOverBudget: Bool { limit > 0 && spent > limit }
    private var tint: Color { Color(hex: category.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundStyle(tint)
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(spent.formattedCurrency) / \(limit.formattedCurrency)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(isOverBudget ? .red : tint)

            if isOverBudget {
                Text("Over budget by \((spent - limit).formattedCurrency)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }
}
