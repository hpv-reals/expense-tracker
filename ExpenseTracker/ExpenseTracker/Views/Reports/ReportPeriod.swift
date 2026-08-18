import Foundation

/// A reporting window shown in the Reports tab.
///
/// `thisWeek`/`thisMonth`/`quarter`/`year` are rolling "start of period through
/// now" windows. `yesterday`/`lastWeek`/`lastMonth` are complete, already-finished
/// calendar periods that exclude today. `custom` has no fixed range of its own —
/// ReportsView supplies a user-picked start/end date instead of calling `range(reference:)`.
enum ReportPeriod: String, CaseIterable, Identifiable {
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case quarter = "Quarter"
    case year = "Year"
    case custom = "Custom Range"

    var id: String { rawValue }

    /// The `[start, end)` date range this period covers, relative to `reference`.
    /// Not meaningful for `.custom` — callers should use their own date range instead.
    func range(reference: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: reference)
        // End-of-today, not `reference` itself, so "through now" periods include
        // every transaction dated today regardless of the exact time this runs.
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? reference

        switch self {
        case .yesterday:
            let start = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            return (start, startOfToday)

        case .thisWeek:
            let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            return (start, endOfToday)

        case .lastWeek:
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: reference)?.start ?? startOfToday
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
            return (start, currentWeekStart)

        case .thisMonth:
            let start = Self.startOfMonth(containing: reference, calendar: calendar)
            return (start, endOfToday)

        case .lastMonth:
            let currentMonthStart = Self.startOfMonth(containing: reference, calendar: calendar)
            let start = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
            return (start, currentMonthStart)

        case .quarter:
            let month = calendar.component(.month, from: reference)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: reference)
            components.month = quarterStartMonth
            components.day = 1
            let start = calendar.date(from: components) ?? reference
            return (start, endOfToday)

        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: reference)) ?? reference
            return (start, endOfToday)

        case .custom:
            return (startOfToday, endOfToday)
        }
    }

    private static func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
