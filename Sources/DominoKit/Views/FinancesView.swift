import SwiftUI

// MARK: - Finances Sub-tabs

private enum FinancesTab: String, CaseIterable, Identifiable {
    case entries
    case transactions
    case summary
    case upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entries: "Entries"
        case .transactions: "Transactions"
        case .summary: "Summary"
        case .upcoming: "Upcoming"
        }
    }

    var icon: String {
        switch self {
        case .entries: "list.bullet.rectangle"
        case .transactions: "arrow.left.arrow.right"
        case .summary: "chart.pie"
        case .upcoming: "calendar"
        }
    }
}

// MARK: - Main Finances View

package struct FinancesView: View {
    @ObservedObject var viewModel: DominoViewModel
    @State private var selectedTab: FinancesTab = .entries

    package var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 180)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            ForEach(FinancesTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 16)
                        Text(tab.title)
                        Spacer()
                    }
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(0.1))
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .entries:
            EntriesListView(viewModel: viewModel)
        case .transactions:
            TransactionsListView(viewModel: viewModel)
        case .summary:
            MonthlySummaryView(viewModel: viewModel)
        case .upcoming:
            UpcomingDuesView(viewModel: viewModel)
        }
    }
}

// MARK: - Entries List

private struct EntriesListView: View {
    @ObservedObject var viewModel: DominoViewModel
    @State private var showingAddEntry = false
    @State private var editingEntry: FinancialEntry?
    @State private var filterType: FinancialEntryType?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            entriesTable
        }
        .sheet(isPresented: $showingAddEntry) {
            EntryEditorView(viewModel: viewModel, entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(viewModel: viewModel, entry: entry)
        }
    }

    private var header: some View {
        HStack {
            Text("Financial Entries")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Picker("", selection: $filterType) {
                Text("All").tag(nil as FinancialEntryType?)
                Text("Income").tag(FinancialEntryType.income as FinancialEntryType?)
                Text("Expense").tag(FinancialEntryType.expense as FinancialEntryType?)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Button {
                showingAddEntry = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
    }

    private var filteredEntries: [FinancialEntry] {
        viewModel.financialEntries.values
            .filter { entry in
                if let filter = filterType { return entry.type == filter }
                return true
            }
            .sorted { $0.name < $1.name }
    }

    private var entriesTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEntries) { entry in
                    EntryRow(entry: entry, onEdit: { editingEntry = entry }, onDelete: {
                        viewModel.deleteFinancialEntry(entry.id)
                    })
                    Divider()
                }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: FinancialEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name.isEmpty ? "Untitled" : entry.name)
                        .font(.system(size: 14, weight: .medium))
                    if !entry.isActive {
                        Text("Paused")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                }

                Text(entry.recurrence.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.type == .income ? "+\(formatAmount(entry.amount))" : "-\(formatAmount(entry.amount))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(entry.type == .income ? .green : .primary)

            if let category = entry.category, !category.isEmpty {
                Text(category)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }

            Menu {
                Button("Edit") { onEdit() }
                Button("Delete", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Entry Editor

private struct EntryEditorView: View {
    @ObservedObject var viewModel: DominoViewModel
    let entry: FinancialEntry?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: FinancialEntryType = .expense
    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var isActive: Bool = true

    // Recurrence state
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var interval: Int = 1
    @State private var selectedWeekdays: Set<Weekday> = []
    @State private var monthDay: Int = 1
    @State private var monthDayMode: MonthDayMode = .dayOfMonth
    @State private var nthOccurrence: Int = 1
    @State private var nthWeekday: Weekday = .monday
    @State private var yearMonth: Int = 1
    @State private var yearDay: Int = 1
    @State private var hasEnd: Bool = false
    @State private var endDate: Date = Date().addingTimeInterval(365 * 24 * 3600)

    private enum MonthDayMode: String, CaseIterable {
        case dayOfMonth
        case weekdayOfMonth
    }

    var isEditing: Bool { entry != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
                .padding(16)
        }
        .frame(width: 480, height: 560)
        .onAppear { loadEntry() }
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Entry" : "New Entry")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.borderless)
            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Name
                LabeledContent("Name") {
                    TextField("e.g. Rent, Salary", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Type + Amount
                HStack {
                    LabeledContent("Type") {
                        Picker("", selection: $type) {
                            ForEach(FinancialEntryType.allCases, id: \.self) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    LabeledContent("Amount") {
                        HStack(spacing: 2) {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $amount)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                // Category
                LabeledContent("Category") {
                    TextField("Optional", text: $category)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Active", isOn: $isActive)

                Divider()

                // Recurrence
                Text("Recurrence")
                    .font(.system(size: 13, weight: .semibold))

                LabeledContent("Every") {
                    HStack(spacing: 6) {
                        Stepper("\(interval)", value: $interval, in: 1...999)
                            .frame(width: 100)
                        Picker("", selection: $frequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { f in
                                Text(interval == 1 ? f.displayName : "\(f.displayName)s").tag(f)
                            }
                        }
                    }
                }

                // Frequency-specific options
                switch frequency {
                case .daily:
                    EmptyView()

                case .weekly:
                    weekdayPicker

                case .monthly:
                    monthlyOptions

                case .yearly:
                    yearlyOptions
                }

                Divider()

                // End condition
                Toggle("End date", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Divider()

                // Preview
                HStack {
                    Text("Preview:")
                        .foregroundStyle(.secondary)
                    Text(buildRecurrence().description)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
            }
        }
    }

    private var weekdayPicker: some View {
        LabeledContent("On") {
            HStack(spacing: 4) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button {
                        if selectedWeekdays.contains(day) {
                            selectedWeekdays.remove(day)
                        } else {
                            selectedWeekdays.insert(day)
                        }
                    } label: {
                        Text(day.shortName)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 32, height: 28)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(selectedWeekdays.contains(day) ? Color.accentColor : Color.primary.opacity(0.06))
                            }
                            .foregroundStyle(selectedWeekdays.contains(day) ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var monthlyOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Pattern", selection: $monthDayMode) {
                Text("Day of month").tag(MonthDayMode.dayOfMonth)
                Text("Nth weekday").tag(MonthDayMode.weekdayOfMonth)
            }
            .pickerStyle(.radioGroup)

            switch monthDayMode {
            case .dayOfMonth:
                LabeledContent("Day") {
                    HStack {
                        Stepper("\(monthDay)", value: $monthDay, in: 1...31)
                            .frame(width: 100)
                        if monthDay == 31 {
                            Text("(last day if month is shorter)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            case .weekdayOfMonth:
                HStack {
                    Picker("Occurrence", selection: $nthOccurrence) {
                        Text("First").tag(1)
                        Text("Second").tag(2)
                        Text("Third").tag(3)
                        Text("Fourth").tag(4)
                        Text("Last").tag(-1)
                    }
                    .frame(width: 100)

                    Picker("Weekday", selection: $nthWeekday) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Text(day.shortName).tag(day)
                        }
                    }
                }
            }
        }
    }

    private var yearlyOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Month") {
                Picker("", selection: $yearMonth) {
                    let formatter = DateFormatter()
                    ForEach(1...12, id: \.self) { m in
                        Text(formatter.monthSymbols[m - 1]).tag(m)
                    }
                }
                .frame(width: 140)
            }

            LabeledContent("Day") {
                Stepper("\(yearDay)", value: $yearDay, in: 1...31)
                    .frame(width: 100)
            }
        }
    }

    private func buildRecurrence() -> Recurrence {
        let end: RecurrenceEnd = hasEnd ? .until(endDate) : .never

        switch frequency {
        case .daily:
            return Recurrence(frequency: .daily, interval: interval, end: end)

        case .weekly:
            let days = selectedWeekdays.isEmpty ? Array(Weekday.allCases) : Array(selectedWeekdays).sorted()
            return Recurrence(frequency: .weekly, interval: interval, byWeekday: days, end: end)

        case .monthly:
            switch monthDayMode {
            case .dayOfMonth:
                return Recurrence(frequency: .monthly, interval: interval, byMonthDay: [monthDay], end: end)
            case .weekdayOfMonth:
                return Recurrence(
                    frequency: .monthly,
                    interval: interval,
                    byWeekday: [nthWeekday],
                    byMonthDay: [nthOccurrence],
                    end: end
                )
            }

        case .yearly:
            return Recurrence(
                frequency: .yearly,
                interval: interval,
                byMonthDay: [yearDay],
                byMonth: yearMonth,
                end: end
            )
        }
    }

    private func loadEntry() {
        guard let entry else { return }
        name = entry.name
        type = entry.type
        amount = String(format: "%.2f", entry.amount)
        category = entry.category ?? ""
        isActive = entry.isActive

        let rec = entry.recurrence
        frequency = rec.frequency
        interval = rec.interval

        if let weekdays = rec.byWeekday {
            selectedWeekdays = Set(weekdays)
        }
        if let days = rec.byMonthDay, let first = days.first {
            if rec.frequency == .monthly && rec.byWeekday != nil {
                monthDayMode = .weekdayOfMonth
                nthOccurrence = first
                if let wd = rec.byWeekday?.first {
                    nthWeekday = wd
                }
            } else {
                monthDayMode = .dayOfMonth
                monthDay = first
            }
        }
        if let month = rec.byMonth {
            yearMonth = month
        }
        if let days = rec.byMonthDay, let first = days.first, rec.frequency == .yearly {
            yearDay = first
        }

        switch rec.end {
        case .never:
            hasEnd = false
        case .until(let date):
            hasEnd = true
            endDate = date
        case .count:
            hasEnd = false
        }
    }

    private func save() {
        let amountValue = Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
        var recurrence = buildRecurrence()
        recurrence.startDate = entry?.createdAt ?? Date()

        let saved = FinancialEntry(
            id: entry?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            amount: amountValue,
            recurrence: recurrence,
            category: category.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            isActive: isActive,
            createdAt: entry?.createdAt ?? Date()
        )

        if isEditing {
            viewModel.updateFinancialEntry(saved)
        } else {
            viewModel.addFinancialEntry(saved)
        }
        dismiss()
    }
}

// MARK: - Transactions List

private struct TransactionsListView: View {
    @ObservedObject var viewModel: DominoViewModel
    @State private var showingAddTransaction = false
    @State private var filterMonth: Int
    @State private var filterYear: Int
    @State private var editingTransaction: FinancialTransaction?

    init(viewModel: DominoViewModel) {
        self.viewModel = viewModel
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        _filterMonth = State(initialValue: comps.month ?? 1)
        _filterYear = State(initialValue: comps.year ?? 2026)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transactionsList
        }
        .sheet(isPresented: $showingAddTransaction) {
            TransactionEditorView(viewModel: viewModel, transaction: nil, defaultMonth: filterMonth, defaultYear: filterYear)
        }
        .sheet(item: $editingTransaction) { txn in
            TransactionEditorView(viewModel: viewModel, transaction: txn, defaultMonth: filterMonth, defaultYear: filterYear)
        }
    }

    private var header: some View {
        HStack {
            Text("Transactions")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            monthPicker

            Button {
                showingAddTransaction = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
    }

    private var monthPicker: some View {
        HStack(spacing: 4) {
            Button {
                previousMonth()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(monthYearLabel)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 120)

            Button {
                nextMonth()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
        }
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let comps = DateComponents(year: filterYear, month: filterMonth, day: 1)
        guard let date = Calendar.current.date(from: comps) else { return "" }
        return formatter.string(from: date)
    }

    private func previousMonth() {
        filterMonth -= 1
        if filterMonth < 1 {
            filterMonth = 12
            filterYear -= 1
        }
    }

    private func nextMonth() {
        filterMonth += 1
        if filterMonth > 12 {
            filterMonth = 1
            filterYear += 1
        }
    }

    private var filteredTransactions: [FinancialTransaction] {
        viewModel.transactionsForMonth(month: filterMonth, year: filterYear)
    }

    private var transactionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredTransactions.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                            .frame(height: 60)
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No transactions this month")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(filteredTransactions) { txn in
                        TransactionRow(
                            transaction: txn,
                            onEdit: { editingTransaction = txn },
                            onDelete: { viewModel.deleteFinancialTransaction(txn.id) }
                        )
                        Divider()
                    }
                }
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: FinancialTransaction
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(Self.dateFormatter.string(from: transaction.date))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name.isEmpty ? "Untitled" : transaction.name)
                    .font(.system(size: 14, weight: .medium))
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(transaction.type == .income ? "+\(formatAmount(transaction.amount))" : "-\(formatAmount(transaction.amount))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(transaction.type == .income ? .green : .primary)

            Menu {
                Button("Edit") { onEdit() }
                Button("Delete", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Transaction Editor

private struct TransactionEditorView: View {
    @ObservedObject var viewModel: DominoViewModel
    let transaction: FinancialTransaction?
    let defaultMonth: Int
    let defaultYear: Int

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: FinancialEntryType = .expense
    @State private var amount: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var selectedEntryID: UUID?

    var isEditing: Bool { transaction != nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form.padding(16)
        }
        .frame(width: 420, height: 400)
        .onAppear { loadTransaction() }
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Transaction" : "New Transaction")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.borderless)
            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Link to entry
            LabeledContent("From Entry") {
                Picker("", selection: $selectedEntryID) {
                    Text("None (one-off)").tag(nil as UUID?)
                    ForEach(Array(viewModel.financialEntries.values).sorted { $0.name < $1.name }) { entry in
                        Text(entry.name).tag(entry.id as UUID?)
                    }
                }
                .onChange(of: selectedEntryID) { _, id in
                    guard let id, let entry = viewModel.financialEntries[id] else { return }
                    name = entry.name
                    type = entry.type
                    amount = String(format: "%.2f", entry.amount)
                }
            }

            LabeledContent("Name") {
                TextField("e.g. Rent March", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                LabeledContent("Type") {
                    Picker("", selection: $type) {
                        ForEach(FinancialEntryType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                LabeledContent("Amount") {
                    HStack(spacing: 2) {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)

            LabeledContent("Note") {
                TextField("Optional", text: $note)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func loadTransaction() {
        guard let txn = transaction else { return }
        name = txn.name
        type = txn.type
        amount = String(format: "%.2f", txn.amount)
        date = txn.date
        note = txn.note ?? ""
        selectedEntryID = txn.entryID
    }

    private func save() {
        let amountValue = Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0

        let saved = FinancialTransaction(
            id: transaction?.id ?? UUID(),
            entryID: selectedEntryID,
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amountValue,
            type: type,
            date: date,
            note: note.trimmingCharacters(in: .whitespaces).nilIfEmpty
        )

        if isEditing {
            viewModel.updateFinancialTransaction(saved)
        } else {
            viewModel.addFinancialTransaction(saved)
        }
        dismiss()
    }
}

// MARK: - Monthly Summary

private struct MonthlySummaryView: View {
    @ObservedObject var viewModel: DominoViewModel
    @State private var month: Int
    @State private var year: Int

    init(viewModel: DominoViewModel) {
        self.viewModel = viewModel
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        _month = State(initialValue: comps.month ?? 1)
        _year = State(initialValue: comps.year ?? 2026)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            summaryContent
                .padding(20)
        }
    }

    private var header: some View {
        HStack {
            Text("Monthly Summary")
                .font(.system(size: 16, weight: .semibold))
            Spacer()

            HStack(spacing: 4) {
                Button {
                    previousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(monthYearLabel)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 120)

                Button {
                    nextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: comps) else { return "" }
        return formatter.string(from: date)
    }

    private func previousMonth() {
        month -= 1
        if month < 1 { month = 12; year -= 1 }
    }

    private func nextMonth() {
        month += 1
        if month > 12 { month = 1; year += 1 }
    }

    private var summary: (income: Double, expenses: Double, net: Double) {
        viewModel.monthlySummary(month: month, year: year)
    }

    private var summaryContent: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                summaryCard(title: "Income", amount: summary.income, color: .green)
                summaryCard(title: "Expenses", amount: summary.expenses, color: .red)
                summaryCard(title: "Net", amount: summary.net, color: summary.net >= 0 ? .green : .red)
            }

            Divider()

            // Expected vs actual for entries
            let dues = viewModel.expectedDues(month: month, year: year)
            let transactions = viewModel.transactionsForMonth(month: month, year: year)

            if !dues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expected vs Actual")
                        .font(.system(size: 14, weight: .semibold))

                    ForEach(dues, id: \.entry.id) { due in
                        let paid = transactions.contains { txn in
                            txn.entryID == due.entry.id &&
                            Calendar.current.isDate(txn.date, inSameDayAs: due.date)
                        }
                        HStack {
                            Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(paid ? .green : .secondary)
                                .font(.system(size: 12))

                            Text(due.entry.name)
                                .font(.system(size: 13))
                            Spacer()
                            Text(due.date, style: .date)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(formatAmount(due.entry.amount))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(due.entry.type == .income ? .green : .primary)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func summaryCard(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(formatAmount(amount))
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.08))
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let prefix = amount >= 0 ? "$" : "-$"
        return prefix + (formatter.string(from: NSNumber(value: abs(amount))) ?? "\(abs(amount))")
    }
}

// MARK: - Upcoming Dues

private struct UpcomingDuesView: View {
    @ObservedObject var viewModel: DominoViewModel
    @State private var month: Int
    @State private var year: Int

    init(viewModel: DominoViewModel) {
        self.viewModel = viewModel
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        _month = State(initialValue: comps.month ?? 1)
        _year = State(initialValue: comps.year ?? 2026)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            duesList
        }
    }

    private var header: some View {
        HStack {
            Text("Upcoming Dues")
                .font(.system(size: 16, weight: .semibold))
            Spacer()

            HStack(spacing: 4) {
                Button {
                    previousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(monthYearLabel)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 120)

                Button {
                    nextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
    }

    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: comps) else { return "" }
        return formatter.string(from: date)
    }

    private func previousMonth() {
        month -= 1
        if month < 1 { month = 12; year -= 1 }
    }

    private func nextMonth() {
        month += 1
        if month > 12 { month = 1; year += 1 }
    }

    private var dues: [(entry: FinancialEntry, date: Date)] {
        viewModel.expectedDues(month: month, year: year)
    }

    private var transactions: [FinancialTransaction] {
        viewModel.transactionsForMonth(month: month, year: year)
    }

    private var duesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if dues.isEmpty {
                    VStack(spacing: 8) {
                        Spacer().frame(height: 60)
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("No dues this month")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(dues, id: \.entry.id) { due in
                        DueRow(
                            entry: due.entry,
                            date: due.date,
                            isPaid: isPaid(entryID: due.entry.id, date: due.date),
                            onRecord: { recordTransaction(for: due.entry, on: due.date) }
                        )
                        Divider()
                    }
                }
            }
        }
    }

    private func isPaid(entryID: UUID, date: Date) -> Bool {
        transactions.contains { txn in
            txn.entryID == entryID && Calendar.current.isDate(txn.date, inSameDayAs: date)
        }
    }

    private func recordTransaction(for entry: FinancialEntry, on date: Date) {
        let txn = FinancialTransaction(
            entryID: entry.id,
            name: entry.name,
            amount: entry.amount,
            type: entry.type,
            date: date
        )
        viewModel.addFinancialTransaction(txn)
    }
}

private struct DueRow: View {
    let entry: FinancialEntry
    let date: Date
    let isPaid: Bool
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(Self.dateFormatter.string(from: date))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name.isEmpty ? "Untitled" : entry.name)
                    .font(.system(size: 14, weight: .medium))
                Text(entry.recurrence.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.type == .income ? "+\(formatAmount(entry.amount))" : "-\(formatAmount(entry.amount))")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(entry.type == .income ? .green : .primary)

            if isPaid {
                Label("Paid", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Button("Record") { onRecord() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
