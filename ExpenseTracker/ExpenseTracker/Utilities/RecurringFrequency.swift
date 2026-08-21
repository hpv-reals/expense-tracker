import Foundation

/// The 4 recurring-bill frequencies the app offers, each just a number of
/// months — kept as a plain UI-facing helper (not persisted itself) so
/// `RecurringBill` only ever stores the underlying `intervalMonths: Int`.
/// That keeps the model free of enum-typed columns, which is deliberate:
/// SwiftData has repeatedly failed to backfill newly-added enum columns
/// during migration (crashing on read for any pre-existing row), while a
/// plain `Int` always migrates cleanly.
enum RecurringFrequency: Int, CaseIterable, Identifiable {
    case monthly = 1
    case quarterly = 3
    case semiannual = 6
    case yearly = 12

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiannual: return "6 Months"
        case .yearly: return "Yearly"
        }
    }

    var intervalMonths: Int { rawValue }

    /// The display label for a bill's raw `intervalMonths`, falling back to
    /// "Every N months" for a value outside the 4 standard presets (e.g. one
    /// left over from before this set of presets existed).
    static func label(forIntervalMonths months: Int) -> String {
        RecurringFrequency(rawValue: months)?.label ?? "Every \(months) months"
    }
}
