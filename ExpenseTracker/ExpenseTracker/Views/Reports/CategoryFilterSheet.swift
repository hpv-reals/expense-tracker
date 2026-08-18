import SwiftUI

/// Multi-select sheet for narrowing the Reports breakdown to specific categories.
/// `selectedIDs` holds every currently-included category id — the caller seeds it
/// with the full set so "everything selected" is a real, explicit state rather
/// than a magic empty-set sentinel.
struct CategoryFilterSheet: View {
    let categories: [Category]
    @Binding var selectedIDs: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    private var allSelected: Bool {
        selectedIDs.count == categories.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(allSelected ? "Deselect All" : "Select All") {
                        selectedIDs = allSelected ? [] : Set(categories.map(\.id))
                    }
                }

                Section("Categories") {
                    ForEach(categories) { category in
                        Button {
                            toggle(category)
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: category.colorHex).opacity(0.16))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: category.colorHex))
                                }
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedIDs.contains(category.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ category: Category) {
        if selectedIDs.contains(category.id) {
            selectedIDs.remove(category.id)
        } else {
            selectedIDs.insert(category.id)
        }
    }
}
