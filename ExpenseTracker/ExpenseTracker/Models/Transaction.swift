import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var amount: Double = 0
    var date: Date = Date()
    var note: String?
    var type: TransactionType = TransactionType.expense
    var category: Category?
    /// Which ledger (e.g. "Cá nhân" vs "Doanh nghiệp") this transaction
    /// belongs to — see `Workspace`.
    var workspace: Workspace?
    /// Who the money went to / came from ("Tên người nhận").
    var recipientName: String?
    /// The account or wallet it was paid from ("Nguồn chi").
    var sourceName: String?
    /// Transfers only: the account the money landed in ("Đến tài khoản").
    var destinationAccount: String?
    /// `false` while the amount is still pending (not yet paid / received).
    var isSettled: Bool = true

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        note: String? = nil,
        type: TransactionType,
        category: Category? = nil,
        workspace: Workspace? = nil,
        recipientName: String? = nil,
        sourceName: String? = nil,
        destinationAccount: String? = nil,
        isSettled: Bool = true
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.type = type
        self.category = category
        self.workspace = workspace
        self.recipientName = recipientName
        self.sourceName = sourceName
        self.destinationAccount = destinationAccount
        self.isSettled = isSettled
    }
}
