import SwiftUI
import Combine

struct BudgetView: View {
    @EnvironmentObject var shiftStore: ShiftStore
    @EnvironmentObject var budgetStore: BudgetStore
    @EnvironmentObject var languageManager: LanguageManager

    @AppStorage("hourlyRate") private var hourlyRate: String = ""
    @AppStorage("currency") private var currency: String = "zł"

    @State private var now = Date()
    @State private var showEditor = false
    @State private var editingItem: BudgetItem? = nil

    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var monthShifts: [ShiftRecord] {
        shiftStore.shifts.filter {
            Calendar.current.isDate($0.startTime, equalTo: now, toGranularity: .month)
        }
    }

    var plannedSalary: Double {
        monthShifts.reduce(0) { $0 + $1.plannedAmount(hourlyRate: hourlyRate) }
    }

    var earnedSalary: Double {
        monthShifts.reduce(0) { $0 + $1.earnedAmount(hourlyRate: hourlyRate, asOf: now) }
    }

    var allocated: Double {
        budgetStore.items.reduce(0) { $0 + $1.amount }
    }

    var paid: Double {
        budgetStore.items.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    var unassigned: Double {
        plannedSalary - allocated
    }

    var allocationProgress: Double {
        guard plannedSalary > 0 else { return 0 }
        return min(max(allocated / plannedSalary, 0), 1)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    salaryHero
                    summaryRow
                    allocationChart
                    categoriesSection
                }
                .padding(.vertical)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingItem = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                BudgetEditorSheet(
                    item: editingItem,
                    currency: currency,
                    onSave: { item in
                        withAnimation(.spring(response: 0.58, dampingFraction: 0.8)) {
                            if editingItem == nil {
                                budgetStore.add(item)
                            } else {
                                budgetStore.update(item)
                            }
                        }
                        showEditor = false
                    },
                    onDelete: {
                        withAnimation(.spring(response: 0.58, dampingFraction: 0.8)) {
                            if let editingItem {
                                budgetStore.delete(id: editingItem.id)
                            }
                        }
                        showEditor = false
                    }
                )
            }
            .onReceive(ticker) { date in
                withAnimation(.easeInOut(duration: 0.35)) {
                    now = date
                }
            }
        }
    }

    var salaryHero: some View {
        VStack(spacing: 14) {
            Text(monthName())
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(salaryPlanTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                SlotMoneyText(
                    value: plannedSalary,
                    currency: currency,
                    font: .system(size: 44, weight: .semibold, design: .rounded),
                    color: .primary
                )
                .minimumScaleFactor(0.68)
                .lineLimit(1)
            }

            HStack(spacing: 10) {
                BudgetValuePill(
                    label: earnedNowTitle,
                    value: earnedSalary,
                    currency: currency,
                    icon: "checkmark.circle.fill",
                    tint: .green
                )

                BudgetValuePill(
                    label: unassignedTitle,
                    value: unassigned,
                    currency: currency,
                    icon: unassigned >= 0 ? "wallet.pass.fill" : "exclamationmark.triangle.fill",
                    tint: unassigned >= 0 ? .indigo : .red
                )
            }

            ProgressView(value: allocationProgress)
                .tint(unassigned >= 0 ? .indigo : .red)
                .animation(.spring(response: 0.58, dampingFraction: 0.8), value: allocationProgress)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((unassigned >= 0 ? Color.indigo : Color.red).opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal)
        .pressScale()
    }

    var summaryRow: some View {
        HStack(spacing: 12) {
            BudgetMiniCard(
                label: allocatedTitle,
                amount: allocated,
                currency: currency,
                icon: "chart.pie.fill",
                tint: .indigo
            )

            BudgetMiniCard(
                label: paidAlreadyTitle,
                amount: paid,
                currency: currency,
                icon: "checkmark.seal.fill",
                tint: .green
            )

            BudgetMiniCard(
                label: unassignedTitle,
                amount: unassigned,
                currency: currency,
                icon: "wallet.pass.fill",
                tint: unassigned >= 0 ? .orange : .red
            )
        }
        .padding(.horizontal)
    }

    var allocationChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(distributionTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                BudgetDonutChart(items: budgetStore.items)
                    .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(budgetStore.items.filter { $0.amount > 0 }.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color(for: item.colorName))
                                .frame(width: 8, height: 8)

                            Text(item.title)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(formatMoney(item.amount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if budgetStore.items.filter({ $0.amount > 0 }).isEmpty {
                        Text(emptyDistributionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 0.5))
        .cornerRadius(18)
        .padding(.horizontal)
    }

    var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(categoriesTitle)
                    .font(.headline)

                Spacer()

                Button {
                    editingItem = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.indigo)
                }
            }

            ForEach(budgetStore.items) { item in
                BudgetItemRow(
                    item: item,
                    salary: plannedSalary,
                    currency: currency,
                    color: color(for: item.colorName),
                    paidLabel: paidAlreadyTitle,
                    plannedLabel: plannedExpenseTitle,
                    onTogglePaid: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                            var updated = item
                            updated.isPaid.toggle()
                            budgetStore.update(updated)
                        }
                    },
                    onEdit: {
                        editingItem = item
                        showEditor = true
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 0.5))
        .cornerRadius(18)
        .padding(.horizontal)
    }

    func monthName() -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = languageManager.locale
        return f.string(from: now).capitalized
    }

    func formatMoney(_ amount: Double) -> String {
        String(format: "%.2f %@", amount, currency)
    }

    func color(for name: String) -> Color {
        switch name {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "blue": return .blue
        default: return .indigo
        }
    }

    var title: String {
        switch languageManager.language {
        case .english: return "Money"
        case .polish: return "Pieniądze"
        case .ukrainian: return "Гроші"
        }
    }

    var salaryPlanTitle: String {
        switch languageManager.language {
        case .english: return "Month salary plan"
        case .polish: return "Plan wypłaty za miesiąc"
        case .ukrainian: return "План зарплати за місяць"
        }
    }

    var earnedNowTitle: String {
        switch languageManager.language {
        case .english: return "Earned now"
        case .polish: return "Zarobiono teraz"
        case .ukrainian: return "Зароблено зараз"
        }
    }

    var allocatedTitle: String {
        switch languageManager.language {
        case .english: return "Allocated"
        case .polish: return "Rozdzielono"
        case .ukrainian: return "Розподілено"
        }
    }

    var paidAlreadyTitle: String {
        switch languageManager.language {
        case .english: return "Paid already"
        case .polish: return "Już opłacono"
        case .ukrainian: return "Вже оплачено"
        }
    }

    var unassignedTitle: String {
        switch languageManager.language {
        case .english: return "Unassigned"
        case .polish: return "Wolne"
        case .ukrainian: return "Вільно"
        }
    }

    var plannedExpenseTitle: String {
        switch languageManager.language {
        case .english: return "Planned"
        case .polish: return "Zaplanowano"
        case .ukrainian: return "Заплановано"
        }
    }

    var distributionTitle: String {
        switch languageManager.language {
        case .english: return "Salary distribution"
        case .polish: return "Podział wypłaty"
        case .ukrainian: return "Розподіл зарплати"
        }
    }

    var categoriesTitle: String {
        switch languageManager.language {
        case .english: return "Categories"
        case .polish: return "Kategorie"
        case .ukrainian: return "Категорії"
        }
    }

    var emptyDistributionText: String {
        switch languageManager.language {
        case .english: return "Add amounts to build a plan"
        case .polish: return "Dodaj kwoty, aby zbudować plan"
        case .ukrainian: return "Додай суми, щоб скласти план"
        }
    }
}

// MARK: - Slot Money

struct SlotMoneyText: View {
    let value: Double
    let currency: String
    let font: Font
    let color: Color

    @State private var displayedValue: Double = 0
    @State private var spinTask: Task<Void, Never>? = nil

    var body: some View {
        Text(String(format: "%.2f %@", displayedValue, currency))
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear {
                displayedValue = value
            }
            .onChange(of: value) { _, newValue in
                spin(to: newValue)
            }
            .onDisappear {
                spinTask?.cancel()
            }
    }

    func spin(to target: Double) {
        let start = displayedValue
        guard abs(start - target) > 0.009 else {
            displayedValue = target
            return
        }

        spinTask?.cancel()

        spinTask = Task {
            let steps = 18
            let distance = max(abs(target - start), 30)

            for step in 0..<steps {
                if Task.isCancelled { return }

                try? await Task.sleep(nanoseconds: 28_000_000)

                let progress = Double(step) / Double(steps)
                let window = max(distance * (1 - progress), 2)
                var randomValue = target + Double.random(in: -window...window)

                if target >= 0 && start >= 0 {
                    randomValue = max(randomValue, 0)
                }

                await MainActor.run {
                    displayedValue = randomValue
                }
            }

            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    displayedValue = target
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BudgetValuePill: View {
    let label: String
    let value: Double
    let currency: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                SlotMoneyText(
                    value: value,
                    currency: currency,
                    font: .caption,
                    color: tint
                )
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct BudgetMiniCard: View {
    let label: String
    let amount: Double
    let currency: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            SlotMoneyText(
                value: amount,
                currency: currency,
                font: .system(size: 15, weight: .semibold, design: .rounded),
                color: .primary
            )
            .lineLimit(1)
            .minimumScaleFactor(0.65)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct BudgetItemRow: View {
    let item: BudgetItem
    let salary: Double
    let currency: String
    let color: Color
    let paidLabel: String
    let plannedLabel: String
    let onTogglePaid: () -> Void
    let onEdit: () -> Void

    var progress: Double {
        guard salary > 0 else { return 0 }
        return min(max(item.amount / salary, 0), 1)
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: item.iconName)
                        .font(.caption)
                        .foregroundColor(color)
                        .frame(width: 30, height: 30)
                        .background(color.opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(String(format: "%.2f %@", item.amount, currency))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(item.isPaid ? paidLabel : plannedLabel)
                                .font(.caption)
                                .foregroundColor(item.isPaid ? .green : .secondary)
                        }
                    }

                    Spacer()

                    Button(action: onTogglePaid) {
                        Image(systemName: item.isPaid ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(item.isPaid ? .green : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                ProgressView(value: progress)
                    .tint(color)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: progress)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(item.isPaid ? 0.72 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BudgetDonutChart: View {
    let items: [BudgetItem]

    var total: Double {
        items.reduce(0) { $0 + max($1.amount, 0) }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray6), lineWidth: 18)

            if total > 0 {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let start = items.prefix(index).reduce(0) { $0 + max($1.amount, 0) } / total
                    let end = start + max(item.amount, 0) / total

                    Circle()
                        .trim(from: start, to: end)
                        .stroke(color(for: item.colorName), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: total)
                }
            }

            VStack(spacing: 2) {
                Text(total > 0 ? "\(Int(total.rounded()))" : "0")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text("plan")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    func color(for name: String) -> Color {
        switch name {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "blue": return .blue
        default: return .indigo
        }
    }
}

// MARK: - Editor

struct BudgetEditorSheet: View {
    let item: BudgetItem?
    let currency: String
    let onSave: (BudgetItem) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var amountText: String
    @State private var colorName: String
    @State private var iconName: String
    @State private var isPaid: Bool

    let colors = ["indigo", "green", "orange", "blue", "purple", "pink", "red"]
    let icons = ["house.fill", "cart.fill", "bus.fill", "banknote.fill", "creditcard.fill", "sparkles", "heart.fill", "gamecontroller.fill"]

    init(item: BudgetItem?, currency: String, onSave: @escaping (BudgetItem) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.currency = currency
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: item?.title ?? "")
        _amountText = State(initialValue: item.map { String(format: "%.2f", $0.amount) } ?? "")
        _colorName = State(initialValue: item?.colorName ?? "indigo")
        _iconName = State(initialValue: item?.iconName ?? "creditcard.fill")
        _isPaid = State(initialValue: item?.isPaid ?? false)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    TextField("Name", text: $title)

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(currency)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Paid already", isOn: $isPaid)
                }

                Section(header: Text("Style")) {
                    Picker("Color", selection: $colorName) {
                        ForEach(colors, id: \.self) { color in
                            Text(color.capitalized).tag(color)
                        }
                    }

                    Picker("Icon", selection: $iconName) {
                        ForEach(icons, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }
                }

                if item != nil {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "Add expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    func save() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        let amount = max(Double(normalized) ?? 0, 0)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let updated = BudgetItem(
            id: item?.id ?? UUID(),
            title: cleanTitle,
            amount: amount,
            colorName: colorName,
            iconName: iconName,
            isPaid: isPaid
        )

        onSave(updated)
    }
}
