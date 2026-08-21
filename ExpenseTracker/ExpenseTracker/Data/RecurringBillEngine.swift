import Foundation
import SwiftData

/// Turns due `RecurringBill`s into real `Transaction`s.
///
/// Run once per launch (see `ExpenseTrackerApp`): every active bill whose
/// `nextDueDate` has arrived or passed gets a matching expense transaction,
/// then its due date is advanced to the next cycle. A bill can catch up more
/// than one cycle in a single run (e.g. the app wasn't opened for a while).
enum RecurringBillEngine {
    @MainActor
    @discardableResult
    static func processDueBills(context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let bills = try? context.fetch(FetchDescriptor<RecurringBill>()) else { return 0 }
        var createdCount = 0

        for bill in bills where bill.isActive {
            // Cap catch-up so a bill left inactive for years (or a bad date)
            // can't spin this into a long-running/infinite loop.
            var guardCount = 0
            while bill.nextDueDate <= now, guardCount < 120 {
                let transaction = Transaction(
                    amount: bill.amount,
                    date: bill.nextDueDate,
                    note: bill.note ?? bill.name,
                    type: .expense,
                    category: bill.category
                )
                context.insert(transaction)
                createdCount += 1
                guardCount += 1
                bill.cycleCount += 1
                bill.nextDueDate = dueDate(
                    anchor: bill.anchorDate,
                    intervalMonths: bill.intervalMonths,
                    cycle: bill.cycleCount,
                    calendar: calendar
                )
            }
        }

        if createdCount > 0 {
            try? context.save()
        }
        return createdCount
    }

    /// `anchor` advanced by `intervalMonths * cycle` months — always computed
    /// from the fixed anchor, not by repeatedly adding to the previous due
    /// date. That distinction matters: repeatedly adding 1 month to Jan 31
    /// drifts to Feb 28, then Mar 28, then Apr 28 (each step re-clamped from
    /// an already-clamped date), while computing every cycle from the same
    /// Jan 31 anchor correctly lands on Feb 28, then Mar 31, then Apr 30.
    static func dueDate(anchor: Date, intervalMonths: Int, cycle: Int, calendar: Calendar = .current) -> Date {
        let months = max(intervalMonths, 1) * cycle
        return calendar.date(byAdding: .month, value: months, to: anchor) ?? anchor
    }
}
