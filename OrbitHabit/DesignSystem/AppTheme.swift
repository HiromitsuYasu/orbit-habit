import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.016, green: 0.027, blue: 0.070)
    static let surface = Color(red: 0.035, green: 0.055, blue: 0.110)
    static let surfaceElevated = Color(red: 0.055, green: 0.080, blue: 0.145)
    static let accentColor = Color(red: 0.35, green: 0.95, blue: 0.96)
    static let secondaryText = Color(red: 0.61, green: 0.66, blue: 0.74)

    static func color(for token: String) -> Color {
        switch token {
        case "violet": Color(red: 0.67, green: 0.48, blue: 1.00)
        case "lime": Color(red: 0.69, green: 0.94, blue: 0.39)
        case "amber": Color(red: 1.00, green: 0.72, blue: 0.30)
        case "magenta": Color(red: 1.00, green: 0.38, blue: 0.74)
        default: accentColor
        }
    }

    static let accentChoices = ["cyan", "violet", "lime", "amber", "magenta"]
}

struct OrbitCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.17), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct OrbitProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel("進捗")
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

struct HabitIcon: View {
    let name: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.55), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
