import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var period: ReportPeriod = .thisMonth
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd: Date = .now
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var isShowingCategoryFilter = false
    @State private var expandedCategoryID: UUID?
    @StateObject private var keyboard = KeyboardVisibility()

    /// The `[start, end)` range currently in effect — either the selected preset
    /// or the user-picked custom start/end when `period == .custom`.
    private var activeRange: (start: Date, end: Date) {
        guard period == .custom else { return period.range(reference: Date()) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: customStart)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) ?? customEnd
        return (start, end)
    }

    private var periodTransactions: [Transaction] {
        let range = activeRange
        return allTransactions.filter { transaction in
            guard transaction.type == .expense,
                  transaction.date >= range.start, transaction.date < range.end,
                  let categoryID = transaction.category?.id else { return false }
            return selectedCategoryIDs.contains(categoryID)
        }
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

    private var categoryFilterSummary: String {
        if categories.isEmpty || selectedCategoryIDs.count == categories.count {
            return "All"
        } else if selectedCategoryIDs.isEmpty {
            return "None"
        } else {
            return "\(selectedCategoryIDs.count) Selected"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                filterSection

                if categorySpends.isEmpty {
                    ContentUnavailableView(
                        "No expenses",
                        systemImage: "chart.pie",
                        description: Text(emptyStateDescription)
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
            .safeAreaInset(edge: .bottom) {
                FloatingTabBar(selectedTab: $selectedTab)
                    .hidesWhileKeyboardVisible(keyboard)
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $isShowingCategoryFilter) {
                CategoryFilterSheet(categories: categories, selectedIDs: $selectedCategoryIDs)
            }
            .onAppear(perform: seedCategoryFilterIfNeeded)
            .onChange(of: categories) { _, _ in seedCategoryFilterIfNeeded() }
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        Section {
            HStack {
                Label("Period", systemImage: "calendar")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Period", selection: $period) {
                    ForEach(ReportPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .labelsHidden()
            }

            if period == .custom {
                DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                DatePicker("To", selection: $customEnd, in: customStart...Date(), displayedComponents: .date)
            }

            categoryFilterButton
        }
        .listRowSeparator(.hidden)
    }

    private var categoryFilterButton: some View {
        Button {
            isShowingCategoryFilter = true
        } label: {
            HStack {
                Label("Categories", systemImage: "tag")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(categoryFilterSummary)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyStateDescription: String {
        selectedCategoryIDs.count != categories.count
            ? "No expenses match the selected categories for \(period.rawValue.lowercased())"
            : "No expenses recorded for \(period.rawValue.lowercased())"
    }

    /// Defaults the category filter to "everything selected" once categories load,
    /// so the picker starts unfiltered instead of hiding all data.
    private func seedCategoryFilterIfNeeded() {
        guard selectedCategoryIDs.isEmpty, !categories.isEmpty else { return }
        selectedCategoryIDs = Set(categories.map(\.id))
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
