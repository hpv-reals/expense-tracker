import SwiftUI
import SwiftData

/// Sheet presented when tapping a transaction in the Home list, letting the
/// user update its amount, type, category, or note.
struct EditTransactionSheet: View {
    @Bindable var transaction: Transaction

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?

    private var filteredCategories: [Category] {
        categories.filter { $0.defaultType == selectedType }
    }

    private var canSave: Bool {
        guard let amount = Double(amountText), amount > 0 else { return false }
        return selectedCategory != nil
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
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filteredCategories) { category in
                                CategoryChip(category: category, isSelected: selectedCategory?.id == category.id)
                                    .onTapGesture { selectedCategory = category }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Note") {
                    TextField("Note (optional)", text: $note)
                }
            }
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
        amountText = String(format: "%g", transaction.amount)
        note = transaction.note ?? ""
        selectedType = transaction.type
        selectedCategory = transaction.category
    }

    private func save() {
        guard let amount = Double(amountText) else { return }
        transaction.amount = amount
        transaction.note = note.isEmpty ? nil : note
        transaction.type = selectedType
        transaction.category = selectedCategory
        try? modelContext.save()
        dismiss()
    }
}
