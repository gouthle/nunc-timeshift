import SwiftUI
import Combine

struct ShiftPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    var timeText: String {
        String(format: "%02d:%02d - %02d:%02d", startHour, startMinute, endHour, endMinute)
    }
}

struct CalendarView: View {
    @EnvironmentObject var shiftStore: ShiftStore
    @EnvironmentObject var languageManager: LanguageManager
    @AppStorage("hourlyRate") private var hourlyRate: String = ""
    @AppStorage("currency") private var currency: String = "zł"

    @State private var selectedDate: Date? = Date()
    @State private var currentMonth: Date = Date()
    @State private var direction: Int = 0
    @State private var showEditor = false
    @State private var editingShift: ShiftRecord? = nil
    @State private var editorDate: Date = Date()
    @State private var now = Date()

    @State private var presets: [ShiftPreset?] = Array(repeating: nil, count: 3)
    @State private var selectedPresetIndex: Int? = nil
    @State private var showPresetEditor = false
    @State private var editingPresetIndex = 0

    private let calendarTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                monthHeader
                    .appearFromBottom(delay: 0, offset: -20)

                weekdayLabels
                    .appearFromBottom(delay: 0.05, offset: -10)

                daysGrid
                    .transition(.asymmetric(
                        insertion: .offset(x: direction > 0 ? 300 : -300).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                        removal: .offset(x: direction > 0 ? -300 : 300).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                    ))
                    .id(currentMonth)

                presetRow
                    .padding(.bottom, 18)
                    .appearFromBottom(delay: 0.14)

                if let date = selectedDate {
                    detailCard(for: date)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.88).combined(with: .opacity).combined(with: .offset(y: 16)),
                                removal: .scale(scale: 0.92).combined(with: .opacity)
                            )
                        )
                }

                statsRow
                    .appearFromBottom(delay: 0.2)
                    .id(currentMonth)
            }
            .padding()
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 {
                        changeMonth(by: 1)
                    } else if value.translation.width > 40 {
                        changeMonth(by: -1)
                    }
                }
        )
        .sheet(isPresented: $showEditor) {
            ShiftEditorSheet(
                shift: editingShift,
                date: editorDate,
                onSave: { start, end in
                    if let existing = editingShift {
                        var updated = existing
                        updated.startTime = start
                        updated.endTime = end
                        shiftStore.updateShift(updated)
                    } else {
                        shiftStore.addShift(start: start, end: end)
                    }
                    showEditor = false
                },
                onDelete: {
                    if let existing = editingShift {
                        shiftStore.deleteShift(id: existing.id)
                    }
                    showEditor = false
                }
            )
        }
        .sheet(isPresented: $showPresetEditor) {
            PresetEditorSheet(
                preset: presets[editingPresetIndex],
                onSave: { preset in
                    presets[editingPresetIndex] = preset
                    selectedPresetIndex = editingPresetIndex
                    savePresets()
                    showPresetEditor = false
                },
                onDelete: {
                    presets[editingPresetIndex] = nil
                    if selectedPresetIndex == editingPresetIndex {
                        selectedPresetIndex = nil
                    }
                    savePresets()
                    showPresetEditor = false
                }
            )
        }
        .onAppear {
            loadPresets()
        }
        .onReceive(calendarTicker) { date in
            now = date
        }
    }

    var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .bouncyButton(scale: 0.82)

            Spacer()

            Text(monthTitle)
                .font(.title2)
                .fontWeight(.medium)
                .contentTransition(.interpolate)

            Spacer()

            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .bouncyButton(scale: 0.82)
        }
        .padding(.bottom, 20)
    }

    var weekdayLabels: some View {
        HStack {
            ForEach(languageManager.weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
    }

    var daysGrid: some View {
        let days = generateDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
            ForEach(days.indices, id: \.self) { i in
                if let date = days[i] {
                    DayCell(
                        date: date,
                        isToday: Calendar.current.isDateInToday(date),
                        isSelected: selectedDate.map {
                            Calendar.current.isDate($0, inSameDayAs: date)
                        } ?? false,
                        shift: shiftFor(date: date),
                        onTap: {
                            handleDateTap(date)
                        }
                    )
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(.bottom, 14)
    }

    var presetRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                PresetSlotButton(
                    preset: presets[index],
                    isSelected: selectedPresetIndex == index,
                    onTap: {
                        if presets[index] == nil {
                            editingPresetIndex = index
                            showPresetEditor = true
                        } else {
                            withAnimation(.cardSpring) {
                                selectedPresetIndex = selectedPresetIndex == index ? nil : index
                            }
                        }
                    },
                    onEdit: {
                        editingPresetIndex = index
                        showPresetEditor = true
                    },
                    onDelete: {
                        withAnimation(.cardSpring) {
                            presets[index] = nil
                            if selectedPresetIndex == index {
                                selectedPresetIndex = nil
                            }
                            savePresets()
                        }
                    }
                )
                .bouncyButton(scale: 0.9)
            }
        }
    }

    func detailCard(for date: Date) -> some View {
        let shift = shiftFor(date: date)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(for: date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let presetName = shift?.presetName, !presetName.isEmpty {
                        Text(presetName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                Button(action: {
                    editingShift = shift
                    editorDate = date
                    showEditor = true
                }) {
                    Label(
                        shift != nil ? languageManager.str(.edit) : languageManager.str(.add),
                        systemImage: shift != nil ? "pencil" : "plus"
                    )
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .bouncyButton(scale: 0.88)
            }

            if let shift = shift {
                let plannedAmount = shift.plannedAmount(hourlyRate: hourlyRate)
                let earnedAmount = shift.earnedAmount(hourlyRate: hourlyRate, asOf: now)

                HStack(spacing: 6) {
                    Text(formatTime(shift.startTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.indigo)
                        .cornerRadius(10)

                    Text(formatTime(shift.endTime))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                let totalMinutes = Int(shift.workedDuration(asOf: now) / 60)
                let h = totalMinutes / 60
                let m = totalMinutes % 60

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(m > 0
                         ? String(format: languageManager.str(.workedHoursMin), h, m)
                         : String(format: languageManager.str(.workedHours), h))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if plannedAmount > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "banknote")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(formatMoney(earnedAmount)) / \(formatMoney(plannedAmount))")
                                .font(.headline)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }

                        ProgressView(value: shift.earningProgress(asOf: now))
                            .tint(.indigo)
                    }
                    .padding(.top, 2)
                }
            } else {
                Text(selectedPresetHint)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 0.5))
        .cornerRadius(16)
        .padding(.bottom, 20)
        .pressScale()
    }

    var statsRow: some View {
        let monthShifts = shiftsForCurrentMonth()
        let workedHours = monthShifts.reduce(0) { $0 + $1.workedDuration(asOf: now) } / 3600
        let plannedHours = monthShifts.reduce(0) { $0 + $1.plannedDuration } / 3600
        let earned = monthShifts.reduce(0) { $0 + $1.earnedAmount(hourlyRate: hourlyRate, asOf: now) }
        let planned = monthShifts.reduce(0) { $0 + $1.plannedAmount(hourlyRate: hourlyRate) }

        let moneyProgress = planned > 0 ? earned / planned : 0
        let hoursProgress = plannedHours > 0 ? workedHours / plannedHours : 0

        return HStack(spacing: 12) {
            StatCard(
                label: languageManager.str(.earned),
                current: formatMoney(earned),
                total: planned > 0 ? formatMoney(planned) : nil,
                sub: "\(monthShifts.count) \(languageManager.str(.shifts))",
                icon: "banknote",
                tint: .green,
                progress: moneyProgress
            )
            .staggeredAppear(index: 0, baseDelay: 0.15)

            StatCard(
                label: languageManager.str(.worked),
                current: formatHours(workedHours),
                total: plannedHours > 0 ? formatHours(plannedHours) : nil,
                sub: languageManager.str(.thisMonth),
                icon: "clock",
                tint: .indigo,
                progress: hoursProgress
            )
            .staggeredAppear(index: 1, baseDelay: 0.15)
        }
    }

    var selectedPresetHint: String {
        if let preset = selectedPreset {
            return "Tap date to add \(preset.name) · \(preset.timeText)"
        }
        return languageManager.str(.noShift)
    }

    var selectedPreset: ShiftPreset? {
        guard let selectedPresetIndex else { return nil }
        return presets[selectedPresetIndex]
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = languageManager.locale
        return f.string(from: currentMonth).capitalized
    }

    func handleDateTap(_ date: Date) {
        withAnimation(.cardSpring) {
            selectedDate = date

            guard selectedPreset != nil else {
                return
            }

            if let shift = shiftFor(date: date) {
                shiftStore.deleteShift(id: shift.id)
                return
            }

            if let preset = selectedPreset, let range = shiftRange(for: date, preset: preset) {
                shiftStore.addShift(start: range.start, end: range.end, presetName: preset.name)
            }
        }
    }

    func shiftRange(for date: Date, preset: ShiftPreset) -> (start: Date, end: Date)? {
        let cal = Calendar.current

        guard
            let start = cal.date(bySettingHour: preset.startHour, minute: preset.startMinute, second: 0, of: date),
            var end = cal.date(bySettingHour: preset.endHour, minute: preset.endMinute, second: 0, of: date)
        else {
            return nil
        }

        if end <= start {
            end = cal.date(byAdding: .day, value: 1, to: end) ?? end
        }

        return (start, end)
    }

    func loadPresets() {
        guard
            let data = UserDefaults.standard.data(forKey: "shiftPresets"),
            let decoded = try? JSONDecoder().decode([ShiftPreset?].self, from: data)
        else {
            return
        }

        var loaded = decoded
        if loaded.count < 3 {
            loaded.append(contentsOf: Array(repeating: nil, count: 3 - loaded.count))
        }

        presets = Array(loaded.prefix(3))
        selectedPresetIndex = nil
    }

    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: "shiftPresets")
        }
    }

    func changeMonth(by value: Int) {
        direction = value
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) ?? currentMonth
        }
    }

    func generateDays() -> [Date?] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth))!

        var weekday = cal.component(.weekday, from: firstDay) - 2
        if weekday < 0 {
            weekday = 6
        }

        var days: [Date?] = Array(repeating: nil, count: weekday)

        for day in range {
            days.append(cal.date(byAdding: .day, value: day - 1, to: firstDay))
        }

        return days
    }

    func shiftFor(date: Date) -> ShiftRecord? {
        shiftStore.shifts.first {
            Calendar.current.isDate($0.startTime, inSameDayAs: date)
        }
    }

    func shiftsForCurrentMonth() -> [ShiftRecord] {
        shiftStore.shifts.filter {
            Calendar.current.isDate($0.startTime, equalTo: currentMonth, toGranularity: .month)
        }
    }

    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    func formatMoney(_ amount: Double) -> String {
        String(format: "%.2f %@", amount, currency)
    }

    func formatHours(_ hours: Double) -> String {
        switch languageManager.language {
        case .english:
            return String(format: "%.1fh", hours)
        case .polish:
            return String(format: "%.1fg", hours)
        case .ukrainian:
            return String(format: "%.1fгод", hours)
        }
    }

    func dayTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        f.locale = languageManager.locale
        return f.string(from: date).capitalized
    }
}

// MARK: - PresetSlotButton

struct PresetSlotButton: View {
    let preset: ShiftPreset?
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                if let preset {
                    Text(preset.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text(preset.timeText)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.indigo : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.indigo.opacity(0.5) : Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if preset != nil {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }
}

// MARK: - PresetEditorSheet

struct PresetEditorSheet: View {
    let preset: ShiftPreset?
    let onSave: (ShiftPreset) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var startTime: Date
    @State private var endTime: Date

    init(preset: ShiftPreset?, onSave: @escaping (ShiftPreset) -> Void, onDelete: @escaping () -> Void) {
        self.preset = preset
        self.onSave = onSave
        self.onDelete = onDelete

        let cal = Calendar.current
        let today = Date()

        let defaultStart = cal.date(bySettingHour: preset?.startHour ?? 10, minute: preset?.startMinute ?? 0, second: 0, of: today) ?? today
        let defaultEnd = cal.date(bySettingHour: preset?.endHour ?? 15, minute: preset?.endMinute ?? 30, second: 0, of: today) ?? today

        _name = State(initialValue: preset?.name ?? "Work")
        _startTime = State(initialValue: defaultStart)
        _endTime = State(initialValue: defaultEnd)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preset")) {
                    TextField("Name", text: $name)
                }

                Section(header: Text("Time")) {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                if preset != nil {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete preset")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(preset == nil ? "Add preset" : "Edit preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cal = Calendar.current
                        let start = cal.dateComponents([.hour, .minute], from: startTime)
                        let end = cal.dateComponents([.hour, .minute], from: endTime)

                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                        let preset = ShiftPreset(
                            name: trimmedName.isEmpty ? "Work" : trimmedName,
                            startHour: start.hour ?? 10,
                            startMinute: start.minute ?? 0,
                            endHour: end.hour ?? 15,
                            endMinute: end.minute ?? 30
                        )

                        onSave(preset)
                    }
                }
            }
        }
    }
}

// MARK: - ShiftEditorSheet

struct ShiftEditorSheet: View {
    let shift: ShiftRecord?
    let date: Date
    let onSave: (Date, Date) -> Void
    let onDelete: () -> Void

    @State private var startTime: Date
    @State private var endTime: Date

    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    init(shift: ShiftRecord?, date: Date, onSave: @escaping (Date, Date) -> Void, onDelete: @escaping () -> Void) {
        self.shift = shift
        self.date = date
        self.onSave = onSave
        self.onDelete = onDelete

        let cal = Calendar.current
        let base = shift?.startTime ?? cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)!
        let baseEnd = shift?.endTime ?? cal.date(bySettingHour: 17, minute: 0, second: 0, of: date)!

        _startTime = State(initialValue: base)
        _endTime = State(initialValue: baseEnd)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(languageManager.str(.shiftTime))) {
                    DatePicker(languageManager.str(.shiftStart), selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker(languageManager.str(.shiftEnd), selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    let duration = endTime.timeIntervalSince(startTime)

                    if duration > 0 {
                        HStack {
                            Text(languageManager.str(.duration))
                            Spacer()
                            Text(formatDuration(duration))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if shift != nil {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            HStack {
                                Spacer()
                                Text(languageManager.str(.deleteShift))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(shift != nil ? languageManager.str(.editShift) : languageManager.str(.addShift))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.str(.cancel)) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.str(.save)) {
                        onSave(startTime, endTime)
                    }
                    .disabled(endTime <= startTime)
                }
            }
        }
    }

    func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = Int(interval) / 60 % 60
        return "\(h)h \(m)m"
    }
}

// MARK: - DayCell

struct DayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let shift: ShiftRecord?
    let onTap: () -> Void

    @State private var pressed = false

    var shiftColor: Color {
        guard let shift = shift else {
            return .clear
        }

        let hours = shift.duration / 3600

        if hours < 6 {
            return .orange
        }

        if hours < 9 {
            return .green
        }

        return .indigo
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.indigo)
                        .frame(width: 30, height: 30)
                } else if isSelected {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 30, height: 30)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday || isSelected ? .medium : .regular))
                    .foregroundColor(isToday ? .white : .primary)
            }

            Circle()
                .fill(shiftColor)
                .frame(width: 4, height: 4)
                .opacity(shift != nil ? 1 : 0)
                .scaleEffect(shift != nil ? 1 : 0.3)
                .animation(.cardSpring, value: shift != nil)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(pressed ? 0.80 : 1.0)
        .animation(.buttonSpring, value: pressed)
        .contentShape(Rectangle())
        .onTapGesture {
            pressed = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                pressed = false
            }

            onTap()
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let label: String
    let current: String
    let total: String?
    let sub: String
    let icon: String
    let tint: Color
    let progress: Double

    var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 26, height: 26)
                    .background(tint.opacity(0.14))
                    .clipShape(Circle())

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(current)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                if let total = total {
                    Text("/ \(total)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))

                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * CGFloat(clampedProgress))
                            .animation(.spring(response: 0.55, dampingFraction: 0.75), value: clampedProgress)
                    }
                }
                .frame(height: 5)

                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.08), radius: 12, x: 0, y: 6)
        .pressScale()
    }
}
