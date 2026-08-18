import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var period: ReportPeriod = .month
    @State private var expandedCategoryID: UUID?

    private var periodTransactions: [Transaction] {
        let start = period.startDate(reference: Date())
        return allTransactions.filter { $0.type == .expense && $0.date >= start }
    }

    private var categorySpends: [CategorySpend] {
        var totalsByID: [UUID: Double] = [:]
        var categoriesByID: [UUID: Category] = [:]

        for transaction in periodTransactions {
            guard let category = transaction.category else { continue }
            totalsByID[category.id, default: 0] += transaction.amount
            categoriesByID[category.id] = category
        }

        return totalsByID.compactMap { id, total in
            categoriesByID[id].map { CategorySpend(category: $0, total: total) }
        }
        .sorted { $0.total > $1.total }
    }

    private var totalSpent: Double {
        categorySpends.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(ReportPeriod.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowSeparator(.hidden)

                if categorySpends.isEmpty {
                    ContentUnavailableView(
                        "No expenses",
                        systemImage: "chart.pie",
                        description: Text("No expenses recorded for this period")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        pieChart
                            .padding(.vertical, 8)
                    }

                    Section("Breakdown") {
                        ForEach(categorySpends) { item in
                            breakdownRow(for: item)
                        }
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }

    private var pieChart: some View {
        Chart(categorySpends) { item in
            SectorMark(
                angle: .value("Amount", item.total),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: item.category.colorHex))
            .cornerRadius(4)
            .opacity(expandedCategoryID == nil || expandedCategoryID == item.category.id ? 1 : 0.35)
        }
        .frame(height: 240)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(totalSpent.formattedCurrency)
                    .font(.headline)
                Text("Total Spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func breakdownRow(for item: CategorySpend) -> some View {
        Button {
            withAnimation {
                expandedCategoryID = (expandedCategoryID == item.category.id) ? nil : item.category.id
            }
        } label: {
            CategorySpendRow(item: item, percentage: totalSpent > 0 ? item.total / totalSpent : 0)
        }
        .buttonStyle(.plain)

        if expandedCategoryID == item.category.id {
            ForEach(periodTransactions.filter { $0.category?.id == item.category.id }) { transaction in
                HStack {
                    Text(transaction.note?.isEmpty == false ? transaction.note! : transaction.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(transaction.amount.formattedCurrency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
            }
        }
    }
}
