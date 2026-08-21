import Foundation
import SwiftData

/// Turns due `RecurringBill`s into real `Transaction`s.
///
/// Run once per launch (see `ExpenseTrackerApp`): every active bill whose
/// `nextDueDate` has arrived or passed gets a matching expense transaction,
/// then its due date is advanced to next month. A bill can catch up more
/// than one cycle in a single run (e.g. the app wasn't opened for two months).
enum RecurringBillEngine {
    @MainActor
    @discardableResult
    static func processDueBills(context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let bills = try? context.fetch(FetchDescriptor<RecurringBill>()) else { return 0 }
        var createdCount = 0

        for bill in bills where bill.isActive {
            // Cap catch-up at 24 cycles so a bill left inactive for years (or a
            // bad date) can't spin this into a long-running/infinite loop.
            var guardCount = 0
            while bill.nextDueDate <= now, guardCount < 24 {
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
                bill.nextDueDate = nextDueDate(after: bill.nextDueDate, dayOfMonth: bill.dayOfMonth, calendar: calendar)
            }
        }

        if createdCount > 0 {
            try? context.save()
        }
        return createdCount
    }

    /// The due date one calendar month after `date`, landing on `dayOfMonth`
    /// (clamped to that month's actual last day).
    static func nextDueDate(after date: Date, dayOfMonth: Int, calendar: Calendar = .current) -> Date {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return date }
        return dueDate(dayOfMonth: dayOfMonth, in: nextMonth, calendar: calendar)
    }

    /// The due date for `dayOfMonth` within the same month/year as `reference`,
    /// used both to advance a bill and to compute the initial due date when a
    /// new bill is created (this month if that day hasn't passed yet, else next).
    static func dueDate(dayOfMonth: Int, in reference: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month], from: reference)
        let daysInMonth = calendar.range(of: .day, in: .month, for: reference)?.count ?? 28
        components.day = min(dayOfMonth, daysInMonth)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? reference
    }

    /// Initial `nextDueDate` for a freshly-created bill: `dayOfMonth` this
    /// month if that date is still ahead (or is today), otherwise next month.
    static func initialDueDate(dayOfMonth: Int, now: Date = .now, calendar: Calendar = .current) -> Date {
        let candidate = dueDate(dayOfMonth: dayOfMonth, in: now, calendar: calendar)
        if calendar.startOfDay(for: candidate) >= calendar.startOfDay(for: now) {
            return candidate
        }
        return nextDueDate(after: candidate, dayOfMonth: dayOfMonth, calendar: calendar)
    }
}
