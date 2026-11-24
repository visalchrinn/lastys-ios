import LastysCore
import SwiftUI

enum AppTab: CaseIterable {
    case home, calendar, me

    var title: String {
        switch self {
        case .home: return "Home"
        case .calendar: return "Calendar"
        case .me: return "Me"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .calendar: return "calendar"
        case .me: return "person"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home:
                    HomeView(showToast: showToast, openMe: { tab = .me })
                case .calendar:
                    ComingSoonView(title: "Calendar")
                case .me:
                    ComingSoonView(title: "Me")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNav(selection: $tab)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.jakarta(14, .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.ink))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toast)
    }

    private func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }
}

struct BottomNav: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: .medium))
                            .frame(height: 24)
                        Text(item.title)
                            .font(.jakarta(11, .semibold))
                    }
                    .foregroundStyle(selection == item ? Theme.rose : Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
    }
}

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.jakarta(26, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Text("This screen is coming in the next build.")
                .font(.jakarta(14, .medium))
                .foregroundStyle(Theme.muted)
                .card()
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

#Preview {
    RootView()
        .environment(AppModel.preview())
}
