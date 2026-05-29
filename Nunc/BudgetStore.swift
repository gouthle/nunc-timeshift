import Foundation
import Combine

struct BudgetItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var amount: Double
    var colorName: String
    var iconName: String
    var isPaid: Bool

    static let defaults: [BudgetItem] = [
        BudgetItem(title: "Rent", amount: 0, colorName: "indigo", iconName: "house.fill", isPaid: false),
        BudgetItem(title: "Food", amount: 0, colorName: "green", iconName: "cart.fill", isPaid: false),
        BudgetItem(title: "Transport", amount: 0, colorName: "orange", iconName: "bus.fill", isPaid: false),
        BudgetItem(title: "Savings", amount: 0, colorName: "blue", iconName: "banknote.fill", isPaid: false)
    ]
}

final class BudgetStore: ObservableObject {
    @Published var items: [BudgetItem] = []

    private let storageKey = "budgetItems"

    init() {
        load()
    }

    func add(_ item: BudgetItem) {
        items.append(item)
        save()
    }

    func update(_ item: BudgetItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func resetDefaults() {
        items = BudgetItem.defaults
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BudgetItem].self, from: data) {
            items = decoded
        } else {
            items = BudgetItem.defaults
            save()
        }
    }
}
