# PROJECT OVERVIEW: Personal Expense Tracker

**Description:** A minimalist, local-only iOS application for personal financial tracking.
**Target OS:** iOS 17.0+
**Tech Stack:** Swift, SwiftUI, SwiftData (for local offline storage), Swift Charts (for reporting).
**Architecture:** MVVM (Model-View-ViewModel) or direct SwiftUI + SwiftData declarative approach.
**Network Requirement:** ZERO. 100% offline local storage.

## 1. DATA MODELS (SwiftData)

Please implement the following models using `@Model` macro for SwiftData.

### Enum: TransactionType

```swift
enum TransactionType: String, Codable, CaseIterable {
    case expense = "Expense"
    case income = "Income"
    case loan = "Loan Given"
    case debt = "Debt/Borrowed"
}
```

### Model: Category

* `id`: UUID
* `name`: String
* `iconName`: String (SF Symbols name, e.g., "cart.fill")
* `colorHex`: String (Hex code for UI color)
* `defaultType`: TransactionType (e.g., "Food" is usually an expense)
* `limitAmount`: Double? (Optional monthly limit. If nil, no limit)
* `transactions`: [Transaction] (Relationship - Cascade delete rule)

### Model: Transaction

* `id`: UUID
* `amount`: Double
* `date`: Date (Default: Date())
* `note`: String?
* `type`: TransactionType
* `category`: Category? (Relationship)

## 2. APP ARCHITECTURE & UI FLOW

The app should have a `TabView` with 3 main tabs:

### TAB 1: Home (Data Entry & Recent Transactions)

**Top Half (Input Area):**

* A `Picker` (SegmentedControl) to select `TransactionType` (Expense / Income / Loan / Debt). Default is Expense.
* A large text field/numpad for entering the `amount`.
* A horizontal scroll or grid to select a `Category` (filtered based on the selected TransactionType).
* A text field for an optional `note`.
* A prominent "Save" button.

**Bottom Half (Recent List):**

* A `List` showing today's and yesterday's transactions.
* **CRUD Operations:**
* **Delete:** Implement `swipeActions` (trailing) to delete a transaction.
* **Edit:** Tap on a transaction to open an `.sheet` with a pre-filled form to update the amount, category, or note.

### TAB 2: Reports (Charts & Analytics)

* **Time Filter:** A `Picker` (SegmentedControl) at the top: Week | Month | Quarter | Year. Default is Month.
* **Visuals:** Use `Swift Charts` (`SectorMark`) to create a Pie Chart showing the percentage of expenses by Category for the selected period.
* **Detail List:** Below the chart, display a list of categories with their total spent amounts, sorted descending by amount.
* Tapping a category in this list should ideally expand to show the specific transactions (optional but recommended).

### TAB 3: Limits (Budgeting)

* Fetch all `Category` items where `limitAmount != nil`.
* For each category, calculate the total expenses in the current month.
* **UI:** Display a `ProgressView` for each.
* If `totalSpent <= limitAmount`: Progress bar is Green/Blue.
* If `totalSpent > limitAmount`: Progress bar turns Red, and display the overspent amount (e.g., "Over budget by 500,000").

## 3. EXECUTION STEPS FOR THE AGENT

Agent, please execute the development in the following strict order. Verify each step works before proceeding to the next.

**Step 1: Project Initialization**

* Initialize a new standard iOS SwiftUI project.
* Setup the SwiftData `ModelContainer` in the main `@main` App struct.
* Inject the container into the environment.

**Step 2: Model Implementation & Mock Data**

* Create the `TransactionType`, `Category`, and `Transaction` models using SwiftData.
* Write a helper struct/function to pre-populate default categories on first launch (e.g., Food, Transport, Salary, Rent) with appropriate SF Symbols and Hex colors.

**Step 3: Build the Home Tab (Input & List)**

* Create the ViewModel/State logic to handle input.
* Implement the UI for the Home screen.
* Ensure the Category list filters reactively when the TransactionType picker changes.
* Implement adding a new transaction to the SwiftData context.
* Implement Swipe-to-Delete and Tap-to-Edit functionalities for the list.

**Step 4: Build the Reports Tab**

* Create logic to filter transactions by the selected time frame (Week/Month/Quarter/Year).
* Group transactions by Category.
* Use `Chart` and `SectorMark` to render the Pie chart.
* Render the breakdown list below the chart.

**Step 5: Build the Limits Tab**

* Create logic to filter current month's expenses for categories that have a `limitAmount`.
* Build the UI with custom colored progress bars indicating the budget health.

**Step 6: Final Polish**

* Ensure Dark Mode compatibility.
* Ensure proper currency formatting (using `NumberFormatter` or `.formatted(.currency(code: "VND"))` based on device locale).
