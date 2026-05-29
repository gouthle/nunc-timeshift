import SwiftUI

@main
struct NuncApp: App {
    @StateObject var shiftStore = ShiftStore()
    @StateObject var languageManager = LanguageManager()
    @StateObject var budgetStore = BudgetStore()
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(shiftStore)
                .environmentObject(languageManager)
                .environmentObject(budgetStore)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}
