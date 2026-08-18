import Foundation

extension Double {
    /// Formats the value as currency using the device's locale, defaulting to VND
    /// (whole-number amounts, no decimals) when the locale doesn't specify a currency.
    var formattedCurrency: String {
        let code = Locale.current.currency?.identifier ?? "VND"
        return self.formatted(.currency(code: code).precision(.fractionLength(0)))
    }
}
