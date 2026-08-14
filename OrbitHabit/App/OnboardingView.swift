import SwiftUI

struct OrbitHabitRootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.preferences.didCompleteOnboarding {
            RootTabView()
        } else {
            OnboardingView()
        }
    }
}

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            title: "今日のことだけに集中",
            message: "今日が実行日の習慣だけを表示します。",
            symbol: "circle.circle"
        ),
        OnboardingPage(
            title: "積み重ねを可視化",
            message: "連続達成、カレンダー、達成率で振り返れます。",
            symbol: "chart.line.uptrend.xyaxis"
        ),
        OnboardingPage(
            title: "必要なときだけ通知",
            message: "完了済みの習慣には同日の通知を送りません。",
            symbol: "bell.badge"
        )
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: pages[page].symbol)
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(AppTheme.accentColor)
                .frame(width: 132, height: 132)
                .background(AppTheme.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(spacing: 12) {
                Text(pages[page].title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(pages[page].message)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? AppTheme.accentColor : .white.opacity(0.20))
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }

            Spacer()

            Button(action: advance) {
                Text(page == pages.count - 1 ? "始める" : "次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accentColor)
                    .foregroundStyle(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background)
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
            return
        }

        Task {
            _ = await environment.notificationScheduler.requestAuthorization()
            environment.preferences.didCompleteOnboarding = true
        }
    }
}

private struct OnboardingPage {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String
}

#Preview {
    OnboardingView()
        .environment(AppEnvironment.live)
        .preferredColorScheme(.dark)
}
