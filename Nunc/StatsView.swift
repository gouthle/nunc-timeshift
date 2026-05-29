import SwiftUI
import Combine

struct StatsView: View {
    @EnvironmentObject var shiftStore: ShiftStore
    @EnvironmentObject var languageManager: LanguageManager
    @AppStorage("hourlyRate") private var hourlyRate: String = ""
    @AppStorage("currency") private var currency: String = "zł"
    @AppStorage("payDay") private var payDay: Int = 1

    @State private var animateRing = false
    @State private var animateBars = false
    @State private var now = Date()

    private let statsTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var currentMonthShifts: [ShiftRecord] {
        shiftStore.shifts.filter {
            Calendar.current.isDate($0.startTime, equalTo: now, toGranularity: .month)
        }
    }

    var totalHours: Double {
        currentMonthShifts.reduce(0) { $0 + $1.workedDuration(asOf: now) } / 3600
    }

    var plannedHours: Double {
        currentMonthShifts.reduce(0) { $0 + $1.plannedDuration } / 3600
    }

    var earned: Double {
        currentMonthShifts.reduce(0) { $0 + $1.earnedAmount(hourlyRate: hourlyRate, asOf: now) }
    }

    var plannedEarned: Double {
        currentMonthShifts.reduce(0) { $0 + $1.plannedAmount(hourlyRate: hourlyRate) }
    }

    var moneyProgress: Double {
        plannedEarned > 0 ? earned / plannedEarned : 0
    }

    var hoursProgress: Double {
        plannedHours > 0 ? totalHours / plannedHours : 0
    }

    var daysUntilPayDay: Int {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month], from: now)
        components.day = payDay

        var payDate = cal.date(from: components)!

        if payDate <= now {
            payDate = cal.date(byAdding: .month, value: 1, to: payDate)!
        }

        return cal.dateComponents([.day], from: now, to: payDate).day ?? 0
    }

    var shortShifts: [ShiftRecord] {
        currentMonthShifts.filter { $0.duration / 3600 < 6 }
    }

    var normalShifts: [ShiftRecord] {
        currentMonthShifts.filter { $0.duration / 3600 >= 6 && $0.duration / 3600 < 9 }
    }

    var longShifts: [ShiftRecord] {
        currentMonthShifts.filter { $0.duration / 3600 >= 9 }
    }

    var segments: [(Double, Color)] {
        let total = Double(currentMonthShifts.count)
        guard total > 0 else { return [] }

        return [
            (Double(normalShifts.count) / total, .indigo),
            (Double(longShifts.count) / total, .green),
            (Double(shortShifts.count) / total, .orange),
        ]
    }

    var weeklyHours: [(String, Double)] {
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        var result: [(String, Double)] = []

        for week in 0..<5 {
            let weekStart = cal.date(byAdding: .day, value: week * 7, to: startOfMonth)!
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!

            let hours = currentMonthShifts
                .filter { $0.startTime >= weekStart && $0.startTime < weekEnd }
                .reduce(0) { $0 + $1.workedDuration(asOf: now) } / 3600

            if hours > 0 || week < 4 {
                result.append(("\(languageManager.str(.byWeeks).components(separatedBy: " ").first ?? "W") \(week + 1)", hours))
            }
        }

        return result
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatBigCard(
                            label: languageManager.str(.earned),
                            current: formatMoney(earned),
                            total: plannedEarned > 0 ? formatMoney(plannedEarned) : nil,
                            sub: monthName(),
                            icon: "banknote",
                            tint: .green,
                            progress: moneyProgress
                        )
                        .staggeredAppear(index: 0)

                        StatBigCard(
                            label: languageManager.str(.hours),
                            current: String(format: "%.1f", totalHours),
                            total: plannedHours > 0 ? String(format: "%.1f", plannedHours) : nil,
                            sub: "\(currentMonthShifts.count) \(languageManager.str(.shifts))",
                            icon: "clock",
                            tint: .indigo,
                            progress: hoursProgress
                        )
                        .staggeredAppear(index: 1)

                        StatBigCard(
                            label: languageManager.str(.untilPayday),
                            current: "\(daysUntilPayDay)",
                            total: nil,
                            sub: languageManager.str(.days),
                            icon: "calendar.badge.clock",
                            tint: .orange,
                            progress: nil
                        )
                        .staggeredAppear(index: 2)

                        StatBigCard(
                            label: languageManager.str(.longestShift),
                            current: longestShift(),
                            total: nil,
                            sub: languageManager.str(.longestShift),
                            icon: "bolt.fill",
                            tint: .purple,
                            progress: nil
                        )
                        .staggeredAppear(index: 3)
                    }
                    .padding(.horizontal)

                    if !currentMonthShifts.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(languageManager.str(.shiftsByDuration))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            HStack(spacing: 24) {
                                ZStack {
                                    RingChart(segments: segments, animate: animateRing)
                                        .frame(width: 130, height: 130)

                                    VStack(spacing: 2) {
                                        Text("\(currentMonthShifts.count)")
                                            .font(.system(size: 24, weight: .medium))
                                            .contentTransition(.numericText())

                                        Text(languageManager.str(.shifts))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    RingLegendRow(
                                        color: .indigo,
                                        label: languageManager.str(.normal),
                                        count: normalShifts.count,
                                        total: currentMonthShifts.count
                                    )

                                    RingLegendRow(
                                        color: .green,
                                        label: languageManager.str(.long),
                                        count: longShifts.count,
                                        total: currentMonthShifts.count
                                    )

                                    RingLegendRow(
                                        color: .orange,
                                        label: languageManager.str(.short),
                                        count: shortShifts.count,
                                        total: currentMonthShifts.count
                                    )
                                }

                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 0.5))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .appearFromBottom(delay: 0.25)
                    }

                    if !weeklyHours.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(languageManager.str(.byWeeks))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            let maxH = weeklyHours.map { $0.1 }.max() ?? 1

                            ForEach(weeklyHours.indices, id: \.self) { i in
                                let (label, hours) = weeklyHours[i]

                                HStack(spacing: 10) {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 44, alignment: .leading)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(.systemGray6))

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.indigo)
                                                .frame(width: animateBars && hours > 0 ? geo.size.width * CGFloat(hours / maxH) : 0)
                                                .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(Double(i) * 0.09), value: animateBars)
                                        }
                                    }
                                    .frame(height: 8)

                                    Text(hours > 0 ? String(format: "%.1f\(languageManager.str(.hours).prefix(1).lowercased())", hours) : "—")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 36, alignment: .trailing)
                                }
                                .staggeredAppear(index: i, baseDelay: 0.3)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 0.5))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    if currentMonthShifts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)

                            Text(languageManager.str(.statistics))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .appearFromBottom(delay: 0.1)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(languageManager.str(.statistics))
            .onAppear {
                animateRing = false
                animateBars = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.heavyBounce) {
                        animateRing = true
                    }
                    animateBars = true
                }
            }
            .onReceive(statsTicker) { date in
                now = date
            }
        }
        .id(languageManager.language)
    }

    func monthName() -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = languageManager.locale
        return f.string(from: now).capitalized
    }

    func longestShift() -> String {
        guard let max = shiftStore.shifts.max(by: { $0.duration < $1.duration }) else {
            return "—"
        }

        let h = Int(max.duration) / 3600
        let m = Int(max.duration) / 60 % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    func formatMoney(_ amount: Double) -> String {
        String(format: "%.2f %@", amount, currency)
    }
}

// MARK: - RingChart

struct RingChart: View {
    let segments: [(Double, Color)]
    let animate: Bool
    let lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray6), lineWidth: lineWidth)

            ForEach(segments.indices, id: \.self) { i in
                let startAngle = segments[..<i].reduce(0) { $0 + $1.0 }

                AnimatedArc(
                    startAngle: startAngle,
                    endAngle: startAngle + segments[i].0,
                    color: segments[i].1,
                    lineWidth: lineWidth,
                    animate: animate
                )
            }
        }
    }
}

struct AnimatedArc: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let lineWidth: CGFloat
    let animate: Bool

    @State private var progress: Double = 0

    var body: some View {
        Circle()
            .trim(from: startAngle, to: startAngle + (endAngle - startAngle) * progress)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.7, dampingFraction: 0.55).delay(startAngle * 0.5), value: progress)
            .onChange(of: animate) { newValue in
                progress = newValue ? 1.0 : 0.0
            }
            .onAppear {
                if animate {
                    progress = 1.0
                }
            }
    }
}

// MARK: - Supporting views

struct StatBigCard: View {
    let label: String
    let current: String
    let total: String?
    let sub: String
    let icon: String
    let tint: Color
    let progress: Double?

    var clampedProgress: Double {
        min(max(progress ?? 0, 0), 1)
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
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                if let total = total {
                    Text("/ \(total)")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                if progress != nil {
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
                }

                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
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

struct RingLegendRow: View {
    let color: Color
    let label: String
    let count: Int
    let total: Int

    var pct: Int {
        total > 0 ? Int((Double(count) / Double(total) * 100).rounded()) : 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text("\(pct)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
