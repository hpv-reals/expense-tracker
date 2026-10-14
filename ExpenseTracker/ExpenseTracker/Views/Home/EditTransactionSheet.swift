import SwiftUI
import SwiftData

/// Card presented over Home when tapping a transaction in the list — styled
/// like `BudgetEditorCard`/`RecurringBillEditorCard` (a centered card over a
/// dimmed background) rather than a full-screen sheet, so editing a
/// transaction looks and behaves like every other "edit this thing" control
/// in the app instead of standing out as a different kind of screen.
struct EditTransactionSheet: View {
    @Bindable var transaction: Transaction
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var amount: Double = 0
    @State private var note: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var date: Date = .now
    @State private var recipientName: String = ""
    @State private var sourceName: String = ""
    @State private var destinationAccount: String = ""
    @State private var isSettled = true

    private var filteredCategories: [Category] {
        categories.filter { selectedType.accepts($0) }
    }

    private var canSave: Bool {
        amount > 0 && selectedCategory != nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            card
        }
        .onAppear(perform: loadInitialState)
        .dismissKeyboardOnTap()
    }

    private var card: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Edit Transaction")
                    .font(.headline)

                Picker("Type", selection: $selectedType) {
                    ForEach(TransactionType.allCases) { type in
                        Text(type.shortLabel).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedType) {
                    if let current = selectedCategory, !selectedType.accepts(current) {
                        selectedCategory = nil
                    }
                }

                CurrencyAmountField(amount: $amount, font: .system(size: 34, weight: .bold, design: .rounded))

                if filteredCategories.isEmpty {
                    Text("No categories for \(selectedType.shortLabel) yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    CategorySelector(categories: filteredCategories, selection: $selectedCategory)
                }

                DatePicker("Date & Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])

                TextField("Note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)

                TransactionDetailFields(
                    type: selectedType,
                    recipientName: $recipientName,
                    sourceName: $sourceName,
                    destinationAccount: $destinationAccount,
                    isSettled: $isSettled
                )

                VStack(spacing: 12) {
                    Button(action: save) {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSave ? Color.accentColor : Color.gray.opacity(0.3))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSave)

                    HStack(spacing: 12) {
                        Button(action: delete) {
                            Text("Delete")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        cancelButton
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: 340, maxHeight: 620)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(.horizontal, 24)
    }

    private var cancelButton: some View {
        Button(action: onDismiss) {
            Text("Cancel")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func loadInitialState() {
        amount = transaction.amount
        note = transaction.note ?? ""
        selectedType = transaction.type
        selectedCategory = transaction.category
        date = transaction.date
        recipientName = transaction.recipientName ?? ""
        sourceName = transaction.sourceName ?? ""
        destinationAccount = transaction.destinationAccount ?? ""
        isSettled = transaction.isSettled
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func save() {
        guard amount > 0 else { return }
        transaction.amount = amount
        transaction.note = note.isEmpty ? nil : note
        transaction.type = selectedType
        transaction.category = selectedCategory
        transaction.date = date
        transaction.recipientName = trimmedOrNil(recipientName)
        transaction.sourceName = trimmedOrNil(sourceName)
        transaction.destinationAccount = selectedType == .transfer ? trimmedOrNil(destinationAccount) : nil
        transaction.isSettled = isSettled
        try? modelContext.save()
        onDismiss()
    }

    private func delete() {
        modelContext.delete(transaction)
        try? modelContext.save()
        onDismiss()
    }
}
