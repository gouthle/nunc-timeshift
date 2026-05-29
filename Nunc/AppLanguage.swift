import Foundation
import Combine

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case polish = "pl"
    case ukrainian = "uk"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .polish: return "Polski"
        case .ukrainian: return "Українська"
        }
    }
}

class LanguageManager: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        language = AppLanguage(rawValue: saved) ?? .english
    }

    func str(_ key: LocalizedKey) -> String {
        translations[language]?[key] ?? translations[.english]![key]!
    }

    var locale: Locale {
        switch language {
        case .english: return Locale(identifier: "en_US")
        case .polish: return Locale(identifier: "pl_PL")
        case .ukrainian: return Locale(identifier: "uk_UA")
        }
    }

    var weekdays: [String] {
        switch language {
        case .english: return ["Mo","Tu","We","Th","Fr","Sa","Su"]
        case .polish: return ["Pn","Wt","Śr","Cz","Pt","So","Nd"]
        case .ukrainian: return ["Пн","Вт","Ср","Чт","Пт","Сб","Нд"]
        }
    }
}

enum LocalizedKey {
    case appName
    case shiftGoing, shiftDone, readyToWork, startShift, endShift, inShift
    case shiftStart, shiftEnd, shiftTime, duration, deleteShift, editShift, addShift, cancel, save
    case calendar, noShift, edit, add, workedHours, workedHoursMin, averageShift, worked, shifts, thisMonth
    case statistics, earned, hours, untilPayday, days, longestShift, shiftsByDuration, byWeeks
    case short, normal, long
    case settings, salary, payDay, rate, perHour, aboutApp, version, name
    case notifications, remindBeforeEnd, minutesBefore, appearance, theme
    case system, light, dark, exportCSV, deleteAll, language
}

let translations: [AppLanguage: [LocalizedKey: String]] = [
    .english: [
        .appName: "Nunc",
        .shiftGoing: "Shift in progress", .shiftDone: "Shift complete", .readyToWork: "Ready to work?",
        .startShift: "Start shift", .endShift: "End shift", .inShift: "in shift",
        .shiftStart: "Start", .shiftEnd: "End", .shiftTime: "Shift time",
        .duration: "Duration", .deleteShift: "Delete shift", .editShift: "Edit shift",
        .addShift: "Add shift", .cancel: "Cancel", .save: "Save",
        .calendar: "Calendar", .noShift: "No shift", .edit: "Edit", .add: "Add",
        .workedHours: "%d h worked", .workedHoursMin: "%d h %d min worked",
        .averageShift: "Avg shift", .worked: "Worked", .shifts: "shifts", .thisMonth: "this month",
        .statistics: "Statistics", .earned: "Earned", .hours: "Hours", .untilPayday: "Until payday",
        .days: "days", .longestShift: "Longest shift", .shiftsByDuration: "Shifts by duration",
        .byWeeks: "By week (hours)", .short: "<6 h", .normal: "6–9 h", .long: "9+ h",
        .settings: "Settings", .salary: "Salary", .payDay: "Payday", .rate: "Rate",
        .perHour: "Per hour", .aboutApp: "About", .version: "Version", .name: "Name",
        .notifications: "Notifications", .remindBeforeEnd: "Remind before shift ends",
        .minutesBefore: "min before end", .appearance: "Appearance", .theme: "Theme",
        .system: "System", .light: "Light", .dark: "Dark",
        .exportCSV: "Export CSV", .deleteAll: "Delete all shifts", .language: "Language",
    ],
    .polish: [
        .appName: "Nunc",
        .shiftGoing: "Zmiana trwa", .shiftDone: "Zmiana zakończona", .readyToWork: "Gotowy do pracy?",
        .startShift: "Rozpocznij zmianę", .endShift: "Zakończ zmianę", .inShift: "na zmianie",
        .shiftStart: "Początek", .shiftEnd: "Koniec", .shiftTime: "Czas zmiany",
        .duration: "Czas trwania", .deleteShift: "Usuń zmianę", .editShift: "Edytuj zmianę",
        .addShift: "Dodaj zmianę", .cancel: "Anuluj", .save: "Zapisz",
        .calendar: "Kalendarz", .noShift: "Brak zmiany", .edit: "Edytuj", .add: "Dodaj",
        .workedHours: "Przepracowano %d h", .workedHoursMin: "Przepracowano %d h %d min",
        .averageShift: "Śr. zmiana", .worked: "Przepracowano", .shifts: "zmian", .thisMonth: "w tym miesiącu",
        .statistics: "Statystyki", .earned: "Zarobiono", .hours: "Godziny", .untilPayday: "Do wypłaty",
        .days: "dni", .longestShift: "Rekord zmiany", .shiftsByDuration: "Zmiany wg długości",
        .byWeeks: "Tygodniowo (godz.)", .short: "<6 h", .normal: "6–9 h", .long: "9+ h",
        .settings: "Ustawienia", .salary: "Wynagrodzenie", .payDay: "Dzień wypłaty", .rate: "Stawka",
        .perHour: "Za godzinę", .aboutApp: "O aplikacji", .version: "Wersja", .name: "Nazwa",
        .notifications: "Powiadomienia", .remindBeforeEnd: "Przypomnij przed końcem zmiany",
        .minutesBefore: "min przed końcem", .appearance: "Wygląd", .theme: "Motyw",
        .system: "Systemowy", .light: "Jasny", .dark: "Ciemny",
        .exportCSV: "Eksportuj CSV", .deleteAll: "Usuń wszystkie zmiany", .language: "Język",
    ],
    .ukrainian: [
        .appName: "Nunc",
        .shiftGoing: "Зміна йде", .shiftDone: "Зміну завершено", .readyToWork: "Готовий до роботи?",
        .startShift: "Почати зміну", .endShift: "Завершити зміну", .inShift: "на зміні",
        .shiftStart: "Початок", .shiftEnd: "Кінець", .shiftTime: "Час зміни",
        .duration: "Тривалість", .deleteShift: "Видалити зміну", .editShift: "Редагувати зміну",
        .addShift: "Додати зміну", .cancel: "Скасувати", .save: "Зберегти",
        .calendar: "Календар", .noShift: "Немає зміни", .edit: "Редагувати", .add: "Додати",
        .workedHours: "Відпрацьовано %d год", .workedHoursMin: "Відпрацьовано %d год %d хв",
        .averageShift: "Середня зміна", .worked: "Відпрацьовано", .shifts: "змін", .thisMonth: "цього місяця",
        .statistics: "Статистика", .earned: "Зароблено", .hours: "Годин", .untilPayday: "До зарплати",
        .days: "днів", .longestShift: "Рекорд зміни", .shiftsByDuration: "Зміни за тривалістю",
        .byWeeks: "По тижнях (год)", .short: "<6 год", .normal: "6–9 год", .long: "9+ год",
        .settings: "Налаштування", .salary: "Зарплата", .payDay: "День виплати", .rate: "Ставка",
        .perHour: "За годину", .aboutApp: "Про застосунок", .version: "Версія", .name: "Назва",
        .notifications: "Сповіщення", .remindBeforeEnd: "Нагадати до кінця зміни",
        .minutesBefore: "хв до кінця", .appearance: "Оформлення", .theme: "Тема",
        .system: "Системна", .light: "Світла", .dark: "Темна",
        .exportCSV: "Експорт CSV", .deleteAll: "Видалити всі зміни", .language: "Мова",
    ],
]
