import Foundation
import SwiftData

/// A recurring monthly charge (e.g. iCloud, YouTube Premium, rent) that
/// auto-generates its own `Transaction` each time it comes due — see
/// `RecurringBillEngine`.
@Model
final class RecurringBill {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    /// Day of the month the bill is due, 1...31. Months shorter than this
    /// clamp to their last day (e.g. 31 -> Feb 28/29) — see `RecurringBillEngine`.
    var dayOfMonth: Int = 1
    /// The next date this bill will generate a transaction. Advanced by
    /// `RecurringBillEngine` every time it fires.
    var nextDueDate: Date = Date()
    var isActive: Bool = true
    var note: String?
    var category: Category?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        dayOfMonth: Int,
        nextDueDate: Date,
        isActive: Bool = true,
        note: String? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dayOfMonth = dayOfMonth
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.note = note
        self.category = category
    }
}
