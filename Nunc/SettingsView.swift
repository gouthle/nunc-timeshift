import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("payDay") private var payDay: Int = 1
    @AppStorage("hourlyRate") private var hourlyRate: String = ""
    @AppStorage("currency") private var currency: String = "zł"
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"
    @AppStorage("notifyBeforeEnd") private var notifyBeforeEnd: Bool = true
    @AppStorage("notifyMinutes") private var notifyMinutes: Int = 15

    @EnvironmentObject var shiftStore: ShiftStore
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showExportSheet = false
    @State private var exportURL: URL? = nil
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPayDayPicker = false

    let currencies = ["zł", "$", "€", "£", "¥", "₴", "₸", "₺", "₩", "Fr"]

    var body: some View {
        NavigationView {
            Form {

                Section(header: Text(languageManager.str(.salary))) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPayDayPicker.toggle()
                        }
                    }) {
                        HStack {
                            Text(languageManager.str(.payDay))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(payDay)")
                                .foregroundColor(.secondary)
                            Image(systemName: showPayDayPicker ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .animation(.easeInOut(duration: 0.2), value: showPayDayPicker)
                        }
                    }

                    if showPayDayPicker {
                        PayDayPicker(selectedDay: $payDay)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }
                }

                Section(header: Text(languageManager.str(.rate))) {
                    HStack {
                        Text(languageManager.str(.perHour))
                        Spacer()
                        TextField("0.00", text: $hourlyRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Menu {
                            ForEach(currencies, id: \.self) { symbol in
                                Button(action: { currency = symbol }) {
                                    HStack {
                                        Text(symbol)
                                        if currency == symbol {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(currency)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                                .frame(minWidth: 24)
                        }
                    }
                }

                Section(header: Text(languageManager.str(.notifications))) {
                    if notificationStatus == .denied {
                        HStack {
                            Image(systemName: "bell.slash").foregroundColor(.secondary)
                            Text(languageManager.str(.notifications))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Toggle(languageManager.str(.remindBeforeEnd), isOn: $notifyBeforeEnd)
                        if notifyBeforeEnd {
                            Stepper("\(notifyMinutes) \(languageManager.str(.minutesBefore))", value: $notifyMinutes, in: 5...60, step: 5)
                        }
                    }
                }

                Section(header: Text(languageManager.str(.appearance))) {
                    // MARK: - Исправлено: тема
                    Picker(languageManager.str(.theme), selection: $colorSchemeRaw) {
                        Text(languageManager.str(.system)).tag("system")
                        Text(languageManager.str(.light)).tag("light")
                        Text(languageManager.str(.dark)).tag("dark")
                    }
                    .pickerStyle(.segmented)

                    // MARK: - Исправлено: Binding для @EnvironmentObject
                    VStack(alignment: .leading, spacing: 8) {
                        Text(languageManager.str(.language))
                            .font(.body)
                        Picker("", selection: Binding(
                            get: { languageManager.language },
                            set: { languageManager.language = $0 }
                        )) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text(languageManager.str(.statistics))) {
                    Button(action: exportCSV) {
                        Label(languageManager.str(.exportCSV), systemImage: "square.and.arrow.up")
                    }
                    .disabled(shiftStore.shifts.isEmpty)

                    Button(role: .destructive) {
                        shiftStore.shifts.forEach { shiftStore.deleteShift(id: $0.id) }
                    } label: {
                        Label(languageManager.str(.deleteAll), systemImage: "trash")
                    }
                    .disabled(shiftStore.shifts.isEmpty)
                }

                Section(header: Text(languageManager.str(.aboutApp))) {
                    HStack {
                        Text(languageManager.str(.version))
                        Spacer()
                        Text("1.5").foregroundColor(.secondary)
                    }
                    HStack {
                        Text(languageManager.str(.name))
                        Spacer()
                        Text("Nunc").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(languageManager.str(.settings))
            .onAppear { checkNotificationStatus() }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }

    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    func exportCSV() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        var csv = "Start,End,Duration (h)\n"
        for shift in shiftStore.shifts.sorted(by: { $0.startTime < $1.startTime }) {
            let hours = String(format: "%.2f", shift.duration / 3600)
            csv += "\(f.string(from: shift.startTime)),\(f.string(from: shift.endTime)),\(hours)\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nunc_shifts.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showExportSheet = true
    }
}

// MARK: - PayDayPicker

struct PayDayPicker: View {
    @Binding var selectedDay: Int
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    let days = Array(1...31)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { day in
                Button(action: { selectedDay = day }) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: selectedDay == day ? .semibold : .regular))
                        .frame(width: 34, height: 34)
                        .background(selectedDay == day ? Color.indigo : Color(.systemGray6))
                        .foregroundColor(selectedDay == day ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
