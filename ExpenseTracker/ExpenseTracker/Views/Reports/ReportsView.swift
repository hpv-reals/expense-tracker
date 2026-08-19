import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct ReportsView: View {
    @Binding var selectedTab: AppTab

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var period: ReportPeriod = .thisMonth
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd: Date = .now
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var isShowingCategoryFilter = false
    /// The category currently drilled into — set by tapping either its chart
    /// wedge or its legend row (both feed the same selection), and drives the
    /// transaction list shown below.
    @State private var selectedCategoryID: UUID?
    @State private var editingTransaction: Transaction?
    @State private var isShowingImporter = false
    @State private var importResultMessage: String?
    @StateObject private var keyboard = KeyboardVisibility()
    @Environment(\.modelContext) private var modelContext

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
                        chartAndLegend
                            .padding(.vertical, 8)
                    }

                    transactionsSection
                }
            }
            .safeAreaInset(edge: .bottom) {
                FloatingTabBar(selectedTab: $selectedTab)
                    .hidesWhileKeyboardVisible(keyboard)
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $isShowingCategoryFilter) {
                CategoryFilterSheet(categories: categories, selectedIDs: $selectedCategoryIDs)
            }
            .sheet(item: $editingTransaction) { transaction in
                EditTransactionSheet(transaction: transaction)
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                onCompletion: handleImportResult
            )
            .alert(
                "Import CSV",
                isPresented: Binding(
                    get: { importResultMessage != nil },
                    set: { isPresented in if !isPresented { importResultMessage = nil } }
                ),
                presenting: importResultMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .onAppear(perform: seedCategoryFilterIfNeeded)
            .onChange(of: categories) { _, _ in seedCategoryFilterIfNeeded() }
        }
    }

    /// Imports the CSV the user picked (columns: STT, Nội dung, Loại thu/chi,
    /// Danh mục, Số tiền, Ngày), then surfaces a summary — imported vs.
    /// skipped-as-duplicate counts, any categories created along the way, and
    /// the first few row errors if some rows couldn't be parsed.
    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importResultMessage = "Không thể mở file: \(error.localizedDescription)"
        case .success(let url):
            do {
                let summary = try TransactionCSVImporter.importCSV(at: url, context: modelContext)
                importResultMessage = importSummaryText(summary)
            } catch {
                importResultMessage = "Import thất bại: \(error.localizedDescription)"
            }
        }
    }

    private func importSummaryText(_ summary: TransactionCSVImporter.Summary) -> String {
        var lines = ["Đã import \(summary.importedCount) giao dịch."]
        if summary.skippedDuplicateCount > 0 {
            lines.append("Bỏ qua \(summary.skippedDuplicateCount) giao dịch trùng.")
        }
        if !summary.createdCategoryNames.isEmpty {
            lines.append("Đã tạo danh mục mới: \(summary.createdCategoryNames.joined(separator: ", ")).")
        }
        if !summary.rowErrors.isEmpty {
            let shown = summary.rowErrors.prefix(5).joined(separator: "\n")
            let more = summary.rowErrors.count > 5 ? "\n… và \(summary.rowErrors.count - 5) lỗi khác" : ""
            lines.append("Lỗi:\n\(shown)\(more)")
        }
        return lines.joined(separator: "\n")
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

    /// Donut chart on the left, category legend (sorted high → low, same order
    /// as `categorySpends`) on the right — tapping either a wedge or a legend
    /// row selects that category and drives `transactionsSection` below.
    private var chartAndLegend: some View {
        HStack(alignment: .top, spacing: 16) {
            pieChart
                .frame(maxWidth: .infinity)

            legend
                .frame(width: 132, alignment: .leading)
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
            .opacity(selectedCategoryID == nil || selectedCategoryID == item.category.id ? 1 : 0.35)
        }
        .frame(height: 220)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(selectedCategorySpend?.total.formattedCurrency ?? totalSpent.formattedCurrency)
                    .font(.headline)
                    .contentTransition(.numericText())
                Text(selectedCategorySpend?.category.name ?? "Total Spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 130)
            .animation(.easeInOut(duration: 0.15), value: selectedCategoryID)
        }
        // `.chartAngleSelection` never invoked its binding in practice (a Swift
        // Charts/simulator quirk — its drag gesture consumed the touch but the
        // value binding it should have produced never updated), so the wedge
        // that was actually tapped is instead worked out by hand: convert the
        // tap point into an angle around the donut's center, then walk
        // `categorySpends` cumulatively — same order the wedges are drawn in —
        // to find which one that angle falls in.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard let matched = category(atPoint: value.location, in: geometry.size) else { return }
                                withAnimation { toggleSelection(matched.category.id) }
                            }
                    )
            }
        }
    }

    /// Maps a tap point (in the chart overlay's local coordinate space) to
    /// whichever category's wedge is drawn under it, or `nil` if the tap
    /// landed outside the donut ring (the hollow center or past its outer edge).
    private func category(atPoint point: CGPoint, in size: CGSize) -> CategorySpend? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = (dx * dx + dy * dy).squareRoot()

        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.6 // matches `innerRadius: .ratio(0.6)` above
        guard (innerRadius...outerRadius).contains(distance) else { return nil }

        // SectorMark draws its first item starting at 12 o'clock and proceeds
        // clockwise, so measure the tap the same way: 0 at the top, increasing
        // clockwise, normalized to a 0..<2π sweep.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        let fraction = angle / (2 * .pi)
        return category(forAngleValue: fraction * totalSpent)
    }

    /// Sorted high → low (inherited from `categorySpends`), each row a color
    /// square + name matching its chart wedge, plus the amount that ordering
    /// is based on.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(categorySpends) { item in
                Button {
                    withAnimation { toggleSelection(item.category.id) }
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: item.category.colorHex))
                            .frame(width: 10, height: 10)
                            .padding(.top, 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.category.name)
                                .font(.caption)
                                .fontWeight(selectedCategoryID == item.category.id ? .semibold : .regular)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(item.total.formattedCurrency)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(selectedCategoryID == nil || selectedCategoryID == item.category.id ? 1 : 0.4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// All transactions for the active period/category filter, narrowed further
    /// to whichever category is drilled into (if any) — starts out showing
    /// everything so the list isn't empty just because the user hasn't tapped
    /// a wedge or legend row yet; tapping one narrows it, and "Clear" (or
    /// tapping the same wedge/row again) goes back to the full list. Grouped
    /// by day underneath that (same "Today" / "Yesterday" / `dd-MM-yyyy"
    /// scheme as Home) since each row only shows a time, not a date. Rows
    /// support the same tap-to-edit / swipe-to-delete as Home.
    @ViewBuilder
    private var transactionsSection: some View {
        // Only shown once a category is drilled into — it's the sole place
        // to back out via "Clear"; unfiltered, the day-group headers below
        // already read fine on their own without a redundant "Transactions"
        // label above them.
        if let selected = selectedCategorySpend {
            HStack {
                Text(selected.category.name)
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation { selectedCategoryID = nil }
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
            }
            .listRowSeparator(.hidden)
        }

        ForEach(groupedDisplayedTransactions, id: \.title) { group in
            Section(group.title) {
                ForEach(group.items) { transaction in
                    TransactionRow(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = transaction }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(transaction)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private var displayedTransactions: [Transaction] {
        guard let selected = selectedCategorySpend else { return periodTransactions }
        return periodTransactions.filter { $0.category?.id == selected.category.id }
    }

    private static let dayGroupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    /// `displayedTransactions` grouped by day (already newest-first, since
    /// `allTransactions` is queried that way and filtering preserves order).
    private var groupedDisplayedTransactions: [(title: String, items: [Transaction])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)

        var groups: [(day: Date, items: [Transaction])] = []
        for transaction in displayedTransactions {
            let day = calendar.startOfDay(for: transaction.date)
            if groups.last?.day == day {
                groups[groups.count - 1].items.append(transaction)
            } else {
                groups.append((day, [transaction]))
            }
        }

        return groups.map { day, items in
            let title: String
            if day == today {
                title = "Today"
            } else if day == yesterday {
                title = "Yesterday"
            } else {
                title = Self.dayGroupFormatter.string(from: day)
            }
            return (title, items)
        }
    }

    private var selectedCategorySpend: CategorySpend? {
        guard let selectedCategoryID else { return nil }
        return categorySpends.first { $0.category.id == selectedCategoryID }
    }

    /// Given a position along the donut's cumulative value sweep (0...`totalSpent`,
    /// see `category(atPoint:in:)`), finds whichever category's running total
    /// first reaches that position — the same order the wedges are drawn in.
    private func category(forAngleValue value: Double) -> CategorySpend? {
        var cumulative: Double = 0
        for item in categorySpends {
            cumulative += item.total
            if value <= cumulative { return item }
        }
        return categorySpends.last
    }

    private func toggleSelection(_ categoryID: UUID) {
        selectedCategoryID = (selectedCategoryID == categoryID) ? nil : categoryID
    }
}
