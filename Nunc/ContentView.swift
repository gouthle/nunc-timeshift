import SwiftUI

enum AppSection {
    case work
    case money
}

struct ContentView: View {
    @EnvironmentObject var languageManager: LanguageManager

    @State private var selectedTab: Int = 0
    @State private var section: AppSection = .work
    @State private var showPremiumSheet = false
    @State private var moneyUnlocked = false
    @State private var unlockFlash = false

    @AppStorage("hasPremium") private var hasPremium: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            sectionSwitcher

            ZStack {
                if section == .work {
                    workTabs
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    BudgetView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: section)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheet(
                title: premiumTitle,
                subtitle: premiumSubtitle,
                onUnlock: {
                    hasPremium = true
                    showPremiumSheet = false
                    openMoney()
                }
            )
        }
        .onChange(of: section) { _, newValue in
            if newValue == .money && hasPremium {
                playUnlockAnimation()
            }

            if newValue == .work {
                moneyUnlocked = false
                unlockFlash = false
            }
        }
    }

    var sectionSwitcher: some View {
        HStack(spacing: 6) {
            sectionButton(
                title: workTitle,
                icon: "timer",
                target: .work
            )

            moneySectionButton
        }
        .padding(5)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    func sectionButton(title: String, icon: String, target: AppSection) -> some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                section = target
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(section == target ? .semibold : .medium)
                .foregroundColor(section == target ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(section == target ? Color.indigo : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    var moneySectionButton: some View {
        Button {
            if hasPremium {
                openMoney()
            } else {
                showPremiumSheet = true
            }
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    if unlockFlash {
                        Circle()
                            .stroke(Color.white.opacity(0.65), lineWidth: 2)
                            .frame(width: 28, height: 28)
                            .scaleEffect(1.55)
                            .opacity(0)
                            .transition(.opacity)
                    }

                    Image(systemName: hasPremium && moneyUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolEffect(.bounce, value: moneyUnlocked)
                        .rotationEffect(.degrees(moneyUnlocked ? -8 : 0))
                        .scaleEffect(moneyUnlocked ? 1.08 : 1.0)
                }
                .frame(width: 22, height: 22)

                Text(moneyTitle)
                    .font(.subheadline)
                    .fontWeight(section == .money ? .semibold : .medium)

                if !hasPremium {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(section == .money ? 0.25 : 0.18))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(section == .money ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(section == .money ? Color.indigo : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    var workTabs: some View {
        TabView(selection: $selectedTab) {
            ShiftView()
                .tabItem {
                    Label(languageManager.str(.startShift), systemImage: "timer")
                }
                .tag(0)

            CalendarView()
                .tabItem {
                    Label(languageManager.str(.calendar), systemImage: "calendar")
                }
                .tag(1)

            StatsView()
                .tabItem {
                    Label(languageManager.str(.statistics), systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(languageManager.str(.settings), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
    }

    func openMoney() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            section = .money
        }

        playUnlockAnimation()
    }

    func playUnlockAnimation() {
        moneyUnlocked = false
        unlockFlash = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                moneyUnlocked = true
                unlockFlash = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            withAnimation(.easeOut(duration: 0.22)) {
                unlockFlash = false
            }
        }
    }

    var workTitle: String {
        switch languageManager.language {
        case .english: return "Work"
        case .polish: return "Praca"
        case .ukrainian: return "Робота"
        }
    }

    var moneyTitle: String {
        switch languageManager.language {
        case .english: return "Money"
        case .polish: return "Pieniądze"
        case .ukrainian: return "Гроші"
        }
    }

    var premiumTitle: String {
        switch languageManager.language {
        case .english: return "Unlock Money"
        case .polish: return "Odblokuj Pieniądze"
        case .ukrainian: return "Відкрити Гроші"
        }
    }

    var premiumSubtitle: String {
        switch languageManager.language {
        case .english: return "Plan your salary, split expenses, and track what is already paid."
        case .polish: return "Planuj wypłatę, dziel wydatki i śledź, co już opłacone."
        case .ukrainian: return "Плануй зарплату, розподіляй витрати і відстежуй, що вже оплачено."
        }
    }
}

// MARK: - Premium Sheet

struct PremiumSheet: View {
    let title: String
    let subtitle: String
    let onUnlock: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var pulse = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.14))
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulse ? 1.08 : 0.96)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.indigo)
                }
                .padding(.top, 30)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 14) {
                    PremiumFeatureRow(icon: "chart.pie.fill", title: "Salary allocation")
                    PremiumFeatureRow(icon: "wallet.pass.fill", title: "Unassigned money")
                    PremiumFeatureRow(icon: "checkmark.seal.fill", title: "Paid tracking")
                }
                .padding(.horizontal)

                Spacer()

                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "faceid")
                        Text("Unlock Premium")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                pulse = true
            }
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.indigo)
                .frame(width: 30, height: 30)
                .background(Color.indigo.opacity(0.14))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
