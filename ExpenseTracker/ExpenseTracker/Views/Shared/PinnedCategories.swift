import Foundation

/// Category names shown as quick-access chips before all others, in this order.
enum PinnedCategories {
    static let names: [String] = ["Ăn uống", "Mua sắm", "Phí tài khoản", "Xe cộ"]
    static let slotCount = 4
}

extension Array where Element == Category {
    /// Splits into up to `PinnedCategories.slotCount` pinned categories — preferring
    /// `PinnedCategories.names` in that order, then filling any remaining slots with
    /// whatever else is available (so types with few categories, like Income/Loan/Debt,
    /// still show everything directly) — plus everything left over as "overflow".
    ///
    /// Replaces a horizontally-scrolling row of chips with a fixed set the user can
    /// tap directly, plus a dropdown for the rest: easier to scan than side-scrolling.
    func splitPinnedAndOverflow() -> (pinned: [Category], overflow: [Category]) {
        var pinned: [Category] = []
        for name in PinnedCategories.names {
            if let match = first(where: { $0.name == name }) {
                pinned.append(match)
            }
        }

        if pinned.count < PinnedCategories.slotCount {
            let usedIDs = Set(pinned.map(\.id))
            let fillers = filter { !usedIDs.contains($0.id) }
            pinned.append(contentsOf: fillers.prefix(PinnedCategories.slotCount - pinned.count))
        }

        let pinnedIDs = Set(pinned.map(\.id))
        let overflow = filter { !pinnedIDs.contains($0.id) }
        return (pinned, overflow)
    }
}
