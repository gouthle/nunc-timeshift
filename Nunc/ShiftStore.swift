import Foundation
import Combine

struct ShiftRecord: Codable, Identifiable {
    var id = UUID()
    var startTime: Date
    var endTime: Date
    var presetName: String? = nil

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var plannedDuration: TimeInterval {
        max(duration, 0)
    }

    func workedDuration(asOf date: Date = Date()) -> TimeInterval {
        guard date > startTime else { return 0 }
        return min(date.timeIntervalSince(startTime), plannedDuration)
    }

    func earningProgress(asOf date: Date = Date()) -> Double {
        guard plannedDuration > 0 else { return 0 }
        return min(workedDuration(asOf: date) / plannedDuration, 1)
    }

    func earnedAmount(hourlyRate: String, asOf date: Date = Date()) -> Double {
        workedDuration(asOf: date) / 3600 * Self.rateValue(from: hourlyRate)
    }

    func plannedAmount(hourlyRate: String) -> Double {
        plannedDuration / 3600 * Self.rateValue(from: hourlyRate)
    }

    static func rateValue(from text: String) -> Double {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return max(Double(normalized) ?? 0, 0)
    }
}

class ShiftStore: ObservableObject {
    @Published var shifts: [ShiftRecord] = []

    init() {
        load()
    }

    func addShift(start: Date, end: Date, presetName: String? = nil) {
        let record = ShiftRecord(startTime: start, endTime: end, presetName: presetName)
        shifts.append(record)
        save()
    }

    func updateShift(_ record: ShiftRecord) {
        if let idx = shifts.firstIndex(where: { $0.id == record.id }) {
            shifts[idx] = record
            save()
        }
    }

    func deleteShift(id: UUID) {
        shifts.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(shifts) {
            UserDefaults.standard.set(encoded, forKey: "shifts")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "shifts"),
           let decoded = try? JSONDecoder().decode([ShiftRecord].self, from: data) {
            shifts = decoded
        }
    }
}
