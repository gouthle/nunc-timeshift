import SwiftUI
import Combine
import UserNotifications

struct ShiftView: View {
    @State private var isWorking = false
    @State private var startTime: Date? = nil
    @State private var endTime: Date? = nil
    @State private var buttonScale: CGFloat = 1.0
    @State private var elapsed: TimeInterval = 0
    @EnvironmentObject var shiftStore: ShiftStore
    @EnvironmentObject var languageManager: LanguageManager

    @AppStorage("shiftDurationHours") private var shiftDurationHours: Double = 8
    @AppStorage("notifyBeforeEnd") private var notifyBeforeEnd: Bool = true
    @AppStorage("notifyMinutes") private var notifyMinutes: Int = 15

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var shiftDuration: TimeInterval { shiftDurationHours * 3600 }

    var progress: Double {
        guard shiftDuration > 0 else { return 0 }
        if isWorking { return min(elapsed / shiftDuration, 1.0) }
        return endTime != nil ? min(elapsed / shiftDuration, 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 30) {

            Text(isWorking
                 ? languageManager.str(.shiftGoing)
                 : (endTime != nil ? languageManager.str(.shiftDone) : languageManager.str(.readyToWork)))
                .font(.largeTitle)
                .fontWeight(.bold)
                .contentTransition(.interpolate)
                .animation(.cardSpring, value: isWorking)
                .appearFromBottom(delay: 0, offset: -30)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)

                VStack(spacing: 4) {
                    Text(formatElapsed(elapsed))
                        .font(.system(size: 36, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if isWorking || endTime != nil {
                        Text(languageManager.str(.inShift))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }
                }
            }
            .frame(width: 200, height: 200)
            .pulse(when: isWorking)
            .appearFromBottom(delay: 0.08)

            if let start = startTime {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(formatTime(start))
                            .font(.title2)
                            .fontWeight(.medium)
                        Text(languageManager.str(.shiftStart))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("—")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(spacing: 4) {
                        Text(endTime != nil ? formatTime(endTime!) : "—")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text(languageManager.str(.shiftEnd))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    )
                )
            }

            Button(action: handleTap) {
                Text(isWorking ? languageManager.str(.endShift) : languageManager.str(.startShift))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 260, height: 56)
                    .background(isWorking ? Color.red : Color.indigo)
                    .cornerRadius(20)
            }
            .bouncyButton(scale: 0.90)
            .animation(.cardSpring, value: isWorking)
            .appearFromBottom(delay: 0.16)
        }
        .onReceive(timer) { _ in
            guard isWorking, let start = startTime else { return }
            elapsed = Date().timeIntervalSince(start)
        }
    }

    func handleTap() {
        withAnimation(.cardSpring) {
            if isWorking {
                let end = Date()
                endTime = end
                isWorking = false
                if let start = startTime {
                    elapsed = end.timeIntervalSince(start)
                    shiftStore.addShift(start: start, end: end)
                }
                cancelShiftNotification()
            } else {
                startTime = Date()
                endTime = nil
                elapsed = 0
                isWorking = true
                scheduleShiftNotification()
            }
        }
    }

    func scheduleShiftNotification() {
        guard notifyBeforeEnd else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = languageManager.str(.shiftGoing)
            content.body = "\(languageManager.str(.minutesBefore)) \(notifyMinutes)"
            content.sound = .default
            let fireIn = shiftDuration - Double(notifyMinutes) * 60
            guard fireIn > 0 else { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            let request = UNNotificationRequest(identifier: "shiftEnd", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelShiftNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["shiftEnd"])
    }

    func formatElapsed(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
