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

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = Date(),
        note: String? = nil,
        type: TransactionType,
        category: Category? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.type = type
        self.category = category
    }
}
