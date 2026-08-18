import SwiftUI
import SwiftData

/// Sheet presented when tapping a transaction in the Home list, letting the
/// user update its amount, type, category, or note.
struct EditTransactionSheet: View {
    @Bindable var transaction: Transaction

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var amount: Double = 0
    @State private var note: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var date: Date = .now

    private var filteredCategories: [Category] {
        categories.filter { $0.defaultType == selectedType }
    }

    private var canSave: Bool {
        amount > 0 && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
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
                }

                Section("Amount") {
                    CurrencyAmountField(amount: $amount, font: .body, alignment: .trailing)
                }

                Section("Category") {
                    CategorySelector(categories: filteredCategories, selection: $selectedCategory)
                        .padding(.vertical, 4)
                }

                Section("Date") {
                    DatePicker("Date & Time", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }

                Section("Note") {
                    TextField("Note (optional)", text: $note)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .dismissKeyboardOnTap()
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: loadInitialState)
    }

    private func loadInitialState() {
        amount = transaction.amount
        note = transaction.note ?? ""
        selectedType = transaction.type
        selectedCategory = transaction.category
        date = transaction.date
    }

    private func save() {
        guard amount > 0 else { return }
        transaction.amount = amount
        transaction.note = note.isEmpty ? nil : note
        transaction.type = selectedType
        transaction.category = selectedCategory
        transaction.date = date
        try? modelContext.save()
        dismiss()
    }
}
