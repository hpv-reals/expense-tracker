import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"

    var id: String { rawValue }

    /// Start date of the period containing `reference`, using the current calendar.
    func startDate(reference: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .week:
            let today = calendar.startOfDay(for: reference)
            return calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: reference)) ?? reference
        case .quarter:
            let month = calendar.component(.month, from: reference)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: reference)
            components.month = quarterStartMonth
            components.day = 1
            return calendar.date(from: components) ?? reference
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: reference)) ?? reference
        }
    }
}
