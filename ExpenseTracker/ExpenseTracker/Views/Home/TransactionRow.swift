import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    private var tint: Color { Color(hex: transaction.category?.colorHex ?? "#8E8E93") }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: transaction.category?.iconName ?? "questionmark.circle")
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category?.name ?? "Uncategorized")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmountText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(transaction.type.isPositiveFlow ? .green : .primary)
                Text(transaction.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var signedAmountText: String {
        let sign = transaction.type.isPositiveFlow ? "+" : "-"
        return sign + transaction.amount.formattedCurrency
    }
}
