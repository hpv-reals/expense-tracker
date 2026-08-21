import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var selectedType: TransactionType = .expense
    @State private var amount: Double = 0
    @State private var selectedCategory: Category?
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var editingTransaction: Transaction?
    @State private var overBudgetAlert: OverBudgetAlert?
    @State private var isInputExpanded = true

    private var filteredCategories: [Category] {
        categories.filter { $0.defaultType == selectedType }
    }

    /// Home only ever shows today's and yesterday's activity — anything
    /// older belongs in Reports, which can slice by week/month/custom range.
    private var groupedTransactions: [(title: String, items: [Transaction])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }

        var todayItems: [Transaction] = []
        var yesterdayItems: [Transaction] = []

        for transaction in allTransactions {
            let day = calendar.startOfDay(for: transaction.date)
            if day == today {
                todayItems.append(transaction)
            } else if day == yesterday {
                yesterdayItems.append(transaction)
            }
        }

        var groups: [(title: String, items: [Transaction])] = []
        if !todayItems.isEmpty { groups.append(("Today", todayItems)) }
        if !yesterdayItems.isEmpty { groups.append(("Yesterday", yesterdayItems)) }
        return groups
    }

    private var canSave: Bool {
        amount > 0 && selectedCategory != nil
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    inputArea
                    Divider()
                    transactionList
                }
                .safeAreaInset(edge: .bottom) {
                    FloatingTabBar.hiddenSpacer(selectedTab: $selectedTab)
                }
                .dismissKeyboardOnTap()
                .navigationTitle("Expense Tracker")
                .alert(
                    "Over Budget",
                    isPresented: Binding(
                        get: { overBudgetAlert != nil },
                        set: { isPresented in if !isPresented { overBudgetAlert = nil } }
                    ),
                    presenting: overBudgetAlert
                ) { _ in
                    Button("OK", role: .cancel) {}
                } message: { alert in
                    Text("\(alert.categoryName) is now \(alert.overBy.formattedCurrency) over its \(alert.limit.formattedCurrency) monthly limit (spent \(alert.spent.formattedCurrency)).")
                }
            }

            if let editingTransaction {
                EditTransactionSheet(transaction: editingTransaction, onDismiss: { self.editingTransaction = nil })
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: editingTransaction?.id)
    }

    // MARK: - Input area

    private var inputArea: some View {
        VStack(spacing: 12) {
            inputAreaHeader

            if isInputExpanded {
                Picker("Type", selection: $selectedType) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.shortLabel).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedType) {
                    if selectedCategory?.defaultType != selectedType {
                        selectedCategory = nil
                    }
                }

                CurrencyAmountField(amount: $amount)
                    .padding(.vertical, 4)

                if filteredCategories.isEmpty {
                    Text("No categories for \(selectedType.shortLabel) yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    CategorySelector(categories: filteredCategories, selection: $selectedCategory)
                        .padding(.horizontal)
                }

                DatePicker("Date & Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .padding(.horizontal)

                TextField("Note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button(action: saveTransaction) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSave)
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, isInputExpanded ? 12 : 4)
    }

    /// Tapping anywhere on the row — not just the chevron — toggles the
    /// section, since a lone small chevron is an easy target to miss.
    private var inputAreaHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isInputExpanded.toggle() }
        } label: {
            HStack {
                Text("Add Transaction")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isInputExpanded ? 0 : -90))
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent list

    private var transactionList: some View {
        List {
            if groupedTransactions.isEmpty {
                ContentUnavailableView(
                    "No transactions yet",
                    systemImage: "tray",
                    description: Text("Add your first transaction above")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedTransactions, id: \.title) { group in
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
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Actions

    private func saveTransaction() {
        guard amount > 0, let category = selectedCategory else { return }
        let savedAmount = amount
        let savedDate = date

        let transaction = Transaction(
            amount: savedAmount,
            date: savedDate,
            note: note.isEmpty ? nil : note,
            type: selectedType,
            category: category
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        checkBudget(for: category, addedAmount: savedAmount, addedDate: savedDate)

        amount = 0
        note = ""
        selectedCategory = nil
        date = .now
    }

    /// Warns when this newly-saved expense pushes its category over its monthly
    /// limit. Computed from the pre-save `allTransactions` snapshot plus the
    /// amount just added, since the @Query hasn't necessarily refreshed yet.
    private func checkBudget(for category: Category, addedAmount: Double, addedDate: Date) {
        guard selectedType == .expense,
              let limit = category.limitAmount,
              Calendar.current.isDate(addedDate, equalTo: .now, toGranularity: .month) else { return }

        let priorSpent = BudgetChecker.spentThisMonth(for: category, transactions: allTransactions)
        let totalSpent = priorSpent + addedAmount
        guard totalSpent > limit else { return }

        overBudgetAlert = OverBudgetAlert(categoryName: category.name, spent: totalSpent, limit: limit)
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

/// Presented when a newly-saved expense pushes its category over its monthly limit.
struct OverBudgetAlert: Identifiable {
    let id = UUID()
    let categoryName: String
    let spent: Double
    let limit: Double
    var overBy: Double { spent - limit }
}
