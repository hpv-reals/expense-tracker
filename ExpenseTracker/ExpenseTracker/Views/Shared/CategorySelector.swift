import SwiftUI

/// The single, shared way to display + pick a category everywhere in the app
/// (Home, Edit Transaction, Add/Edit Budget): up to 4 pinned quick-access
/// chips (see `PinnedCategories`) plus a "More" dropdown for the rest.
///
/// Every screen that lets the user choose a category should use this view —
/// that way a future change to the pinned order, or to the chip/dropdown
/// design, only has to happen in one place (here, `PinnedCategories`, and
/// `CategoryChip`/`MoreCategoryPicker`) instead of being kept in sync by hand
/// across several screens.
struct CategorySelector: View {
    let categories: [Category]
    @Binding var selection: Category?

    /// Each chip (including the "More" slot) is a fixed 64pt wide. An adaptive
    /// grid — rather than a plain HStack — lets the row wrap onto a second line
    /// when it's squeezed into a narrower container (e.g. the centered Budget
    /// card) instead of overflowing past the edge.
    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 64), spacing: 12)]

    var body: some View {
        let split = categories.splitPinnedAndOverflow()
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(split.pinned) { category in
                CategoryChip(category: category, isSelected: selection?.id == category.id)
                    .onTapGesture { selection = category }
            }
            if !split.overflow.isEmpty {
                MoreCategoryPicker(categories: split.overflow, selection: $selection)
            }
        }
    }
}
