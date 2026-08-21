import SwiftUI

struct RecurringBillRow: View {
    let bill: RecurringBill

    private var tint: Color { Color(hex: bill.category?.colorHex ?? "#8E8E93") }

    private var frequencyLabel: String {
        RecurringFrequency.label(forIntervalMonths: bill.intervalMonths)
    }

    private var scheduleLabel: String {
        "\(frequencyLabel) · next \(bill.nextDueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: bill.category?.iconName ?? "arrow.triangle.2.circlepath")
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(scheduleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(bill.amount.formattedCurrency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !bill.isActive {
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(bill.isActive ? 1 : 0.5)
    }
}
