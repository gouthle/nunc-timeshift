import SwiftUI

// MARK: - Spring presets

extension Animation {
    /// Мягкий отскок для карточек
    static var cardSpring: Animation {
        .spring(response: 0.45, dampingFraction: 0.62, blendDuration: 0)
    }
    /// Резкий отскок для кнопок
    static var buttonSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.55, blendDuration: 0)
    }
    /// Плавный залёт для элементов списка
    static var listItemSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
    }
    /// Тяжёлый физичный отскок
    static var heavyBounce: Animation {
        .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)
    }
}

// MARK: - Bouncy button style

struct BouncyButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.88
    var rotation: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? rotation : 0))
            .animation(.buttonSpring, value: configuration.isPressed)
    }
}

extension View {
    func bouncyButton(scale: CGFloat = 0.88, rotation: Double = 0) -> some View {
        self.buttonStyle(BouncyButtonStyle(scale: scale, rotation: rotation))
    }
}

// MARK: - Appear animation modifier

struct AppearModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.85)
            .offset(y: appeared ? 0 : offset)
            .onAppear {
                withAnimation(.cardSpring.delay(delay)) {
                    appeared = true
                }
            }
            .onDisappear {
                appeared = false
            }
    }
}

extension View {
    /// Карточка вылетает снизу с пружиной
    func appearFromBottom(delay: Double = 0, offset: CGFloat = 40) -> some View {
        modifier(AppearModifier(delay: delay, offset: offset))
    }
}

// MARK: - Staggered list appear

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.82)
            .offset(y: appeared ? 0 : 30)
            .onAppear {
                withAnimation(.listItemSpring.delay(baseDelay + Double(index) * 0.07)) {
                    appeared = true
                }
            }
            .onDisappear { appeared = false }
    }
}

extension View {
    func staggeredAppear(index: Int, baseDelay: Double = 0.1) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Press & hold scale

struct PressScaleModifier: ViewModifier {
    @GestureState private var pressing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressing ? 0.94 : 1.0)
            .animation(.buttonSpring, value: pressing)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressing) { _, state, _ in state = true }
            )
    }
}

extension View {
    func pressScale() -> some View {
        modifier(PressScaleModifier())
    }
}

// MARK: - Tab transition

struct TabTransitionModifier: ViewModifier {
    let tab: Int
    let selectedTab: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.93)
            .offset(y: appeared ? 0 : 20)
            .onChange(of: selectedTab) { newTab in
                if newTab == tab {
                    appeared = false
                    withAnimation(.cardSpring.delay(0.05)) {
                        appeared = true
                    }
                }
            }
            .onAppear {
                withAnimation(.cardSpring.delay(0.05)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func tabAppear(tab: Int, selectedTab: Int) -> some View {
        modifier(TabTransitionModifier(tab: tab, selectedTab: selectedTab))
    }
}

// MARK: - Pulse animation (для активной смены)

struct PulseModifier: ViewModifier {
    let active: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.04 : 1.0)
            .animation(
                active
                    ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { if active { pulsing = true } }
            .onChange(of: active) { isActive in
                pulsing = isActive
            }
    }
}

extension View {
    func pulse(when active: Bool) -> some View {
        modifier(PulseModifier(active: active))
    }
}

// MARK: - Shake (для ошибок/disabled)

struct ShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _ in
                withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { offset = -10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.08, dampingFraction: 0.3)) { offset = 10 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.4)) { offset = -6 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) { offset = 0 }
                }
            }
    }
}

extension View {
    func shake(trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}
