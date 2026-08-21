import Foundation
import SwiftData

/// A recurring charge (e.g. iCloud paid monthly, YouTube Premium paid every 6
/// months, an annual subscription) that auto-generates its own `Transaction`
/// each time it comes due — see `RecurringBillEngine`.
@Model
final class RecurringBill {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    /// How often this bill repeats, in months — 1 (monthly), 3 (quarterly),
    /// 6 (every 6 months), or 12 (yearly). Kept as a plain `Int` (not an enum)
    /// so every cycle can be computed as `anchorDate + intervalMonths * N`
    /// with plain calendar month arithmetic.
    var intervalMonths: Int = 1
    /// The due date this schedule is anchored to. Every later due date is
    /// computed from this one fixed date (never from the previous due date),
    /// so cycles land on the intended day instead of drifting — see
    /// `RecurringBillEngine.dueDate`. Reset (along with `cycleCount`)
    /// whenever the schedule itself changes; left alone when only a cosmetic
    /// field (amount, name, category) is edited.
    var anchorDate: Date = Date()
    /// How many cycles have already fired since `anchorDate`.
    var cycleCount: Int = 0
    /// Denormalized cache of `anchorDate` advanced by `cycleCount` cycles —
    /// kept as a stored property (rather than computed) so it's directly
    /// queryable/sortable, and updated by `RecurringBillEngine` whenever
    /// `cycleCount` advances.
    var nextDueDate: Date = Date()
    var isActive: Bool = true
    var note: String?
    var category: Category?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        intervalMonths: Int,
        anchorDate: Date,
        cycleCount: Int = 0,
        nextDueDate: Date,
        isActive: Bool = true,
        note: String? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.intervalMonths = intervalMonths
        self.anchorDate = anchorDate
        self.cycleCount = cycleCount
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.note = note
        self.category = category
    }
}
