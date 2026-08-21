import SwiftUI
import SwiftData

/// Centered card for adding or editing a recurring bill (iCloud, YouTube,
/// rent, ...). Mirrors `BudgetEditorCard`'s layout so the two editors feel
/// like the same family of control inside the Limits tab.
struct RecurringBillEditorCard: View {
    enum Target: Identifiable, Equatable {
        case add
        case edit(RecurringBill)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let bill): return bill.id.uuidString
            }
        }
    }

    let target: Target
    let expenseCategories: [Category]
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var amount: Double = 0
    @State private var dayOfMonth: Int = 1
    @State private var selectedCategory: Category?
    @State private var isActive: Bool = true

    private var existingBill: RecurringBill? {
        if case .edit(let bill) = target { return bill }
        return nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            card
        }
        .onAppear(perform: loadExistingValues)
        .dismissKeyboardOnTap()
    }

    private var card: some View {
        VStack(spacing: 16) {
            Text(existingBill == nil ? "Add Recurring Bill" : "Edit Recurring Bill")
                .font(.headline)

            TextField("Name (e.g. iCloud, YouTube)", text: $name)
                .textFieldStyle(.roundedBorder)

            CurrencyAmountField(amount: $amount, font: .system(size: 34, weight: .bold, design: .rounded))

            dayOfMonthPicker

            if !expenseCategories.isEmpty {
                CategorySelector(categories: expenseCategories, selection: $selectedCategory)
            }

            if existingBill != nil {
                Toggle("Active", isOn: $isActive)
                    .tint(.accentColor)
            }

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

                if existingBill != nil {
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
                } else {
                    cancelButton
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(.horizontal, 24)
    }

    private var dayOfMonthPicker: some View {
        HStack {
            Text("Bills on day")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Day of month", selection: $dayOfMonth) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.menu)
        }
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

    private func loadExistingValues() {
        guard let existingBill else { return }
        name = existingBill.name
        amount = existingBill.amount
        dayOfMonth = existingBill.dayOfMonth
        selectedCategory = existingBill.category
        isActive = existingBill.isActive
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, amount > 0 else { return }

        if let existingBill {
            existingBill.name = trimmedName
            existingBill.amount = amount
            existingBill.category = selectedCategory
            existingBill.isActive = isActive
            // Only reschedule off a changed due day — leave nextDueDate alone
            // otherwise, so editing the amount doesn't reset an already-ticking cycle.
            if existingBill.dayOfMonth != dayOfMonth {
                existingBill.dayOfMonth = dayOfMonth
                existingBill.nextDueDate = RecurringBillEngine.initialDueDate(dayOfMonth: dayOfMonth)
            }
        } else {
            let bill = RecurringBill(
                name: trimmedName,
                amount: amount,
                dayOfMonth: dayOfMonth,
                nextDueDate: RecurringBillEngine.initialDueDate(dayOfMonth: dayOfMonth),
                category: selectedCategory
            )
            modelContext.insert(bill)
        }

        try? modelContext.save()
        onDismiss()
    }

    private func delete() {
        guard let existingBill else { return }
        modelContext.delete(existingBill)
        try? modelContext.save()
        onDismiss()
    }
}
