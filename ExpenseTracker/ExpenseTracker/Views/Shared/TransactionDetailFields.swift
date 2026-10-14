import SwiftUI

/// The optional detail fields shared by the Add (Home) and Edit forms:
/// recipient, source account, destination account (transfers only) and
/// whether the amount is settled yet. Mirrors the CSV template's columns.
struct TransactionDetailFields: View {
    let type: TransactionType
    @Binding var recipientName: String
    @Binding var sourceName: String
    @Binding var destinationAccount: String
    @Binding var isSettled: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField("Recipient (optional)", text: $recipientName)
                .textFieldStyle(.roundedBorder)

            TextField("Source account (optional)", text: $sourceName)
                .textFieldStyle(.roundedBorder)

            if type == .transfer {
                TextField("To account (optional)", text: $destinationAccount)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle(isOn: $isSettled) {
                Text(isSettled ? "Settled" : "Pending")
            }
        }
    }
}
