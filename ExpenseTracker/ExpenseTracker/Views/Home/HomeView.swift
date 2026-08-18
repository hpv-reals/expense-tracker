import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var selectedType: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var note: String = ""
    @State private var editingTransaction: Transaction?
    @FocusState private var amountFieldFocused: Bool

    private var filteredCategories: [Category] {
        categories.filter { $0.defaultType == selectedType }
    }

    /// Transactions dated today or yesterday, grouped for the "Recent" list.
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
        guard let amount = Double(amountText), amount > 0 else { return false }
        return selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputArea
                Divider()
                transactionList
            }
            .navigationTitle("Expense Tracker")
            .sheet(item: $editingTransaction) { transaction in
                EditTransactionSheet(transaction: transaction)
            }
        }
    }

    // MARK: - Input area

    private var inputArea: some View {
        VStack(spacing: 12) {
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

            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($amountFieldFocused)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)

            if filteredCategories.isEmpty {
                Text("No categories for \(selectedType.shortLabel) yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredCategories) { category in
                            CategoryChip(category: category, isSelected: selectedCategory?.id == category.id)
                                .onTapGesture { selectedCategory = category }
                        }
                    }
                    .padding(.horizontal)
                }
            }

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
        .padding(.top, 8)
        .padding(.bottom, 12)
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
    }

    // MARK: - Actions

    private func saveTransaction() {
        guard let amount = Double(amountText), amount > 0, let category = selectedCategory else { return }
        let transaction = Transaction(
            amount: amount,
            date: Date(),
            note: note.isEmpty ? nil : note,
            type: selectedType,
            category: category
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        amountText = ""
        note = ""
        selectedCategory = nil
        amountFieldFocused = false
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}
