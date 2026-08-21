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
    @State private var frequency: RecurringFrequency = .monthly
    @State private var nextDueDate: Date = .now
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

            frequencyPicker

            VStack(alignment: .leading, spacing: 4) {
                DatePicker("Next due date", selection: $nextDueDate, displayedComponents: [.date, .hourAndMinute])
                Text("The transaction is created at this exact time — pick a time you're actually awake for, e.g. 8:00 AM.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Repeats")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Frequency", selection: $frequency) {
                ForEach(RecurringFrequency.allCases) { frequency in
                    Text(frequency.label).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
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
        guard let existingBill else {
            // A brand-new bill defaults to 8 AM today rather than whatever
            // moment "Add Bill" happened to be tapped — firing at 11 PM (or
            // 3 AM) just because that's when the bill was created isn't what
            // anyone wants. Still fully editable via the picker above.
            nextDueDate = Self.defaultNextDueDate()
            return
        }
        name = existingBill.name
        amount = existingBill.amount
        frequency = RecurringFrequency(rawValue: existingBill.intervalMonths) ?? .monthly
        nextDueDate = existingBill.nextDueDate
        selectedCategory = existingBill.category
        isActive = existingBill.isActive
    }

    private static func defaultNextDueDate(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, amount > 0 else { return }

        if let existingBill {
            existingBill.name = trimmedName
            existingBill.amount = amount
            existingBill.category = selectedCategory
            existingBill.isActive = isActive

            // Only reset the schedule (anchor + cycle count) when the
            // schedule itself actually changed — editing just the amount or
            // category shouldn't reset an already-ticking cycle. Compared
            // down to the minute (not just the day) so changing only the
            // time — e.g. moving a bill from 11 PM to 8 AM — is picked up too.
            let scheduleChanged = existingBill.intervalMonths != frequency.intervalMonths
                || existingBill.nextDueDate != nextDueDate
            if scheduleChanged {
                existingBill.intervalMonths = frequency.intervalMonths
                existingBill.anchorDate = nextDueDate
                existingBill.cycleCount = 0
                existingBill.nextDueDate = nextDueDate
            }
        } else {
            let bill = RecurringBill(
                name: trimmedName,
                amount: amount,
                intervalMonths: frequency.intervalMonths,
                anchorDate: nextDueDate,
                nextDueDate: nextDueDate,
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
