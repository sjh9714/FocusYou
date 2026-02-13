import SwiftUI
import AppKit

// MARK: - 설정 내 테마 실시간 프리뷰 패널

struct ThemeLivePreviewPanel: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWindow) private var openWindow

    @State private var previewSurface: PreviewSurface = .dashboard

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            Picker("미리보기", selection: $previewSurface) {
                ForEach(PreviewSurface.allCases) { surface in
                    Text(surface.title).tag(surface)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch previewSurface {
                case .dashboard:
                    dashboardPreviewCard
                case .popover:
                    popoverPreviewCard
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))

            Button {
                openDashboardForLivePreview()
            } label: {
                Label("대시보드 나란히 열기", systemImage: "rectangle.split.2x1")
                    .frame(maxWidth: .infinity)
            }
            .secondaryActionStyle(color: themeManager.primary)

            Label("테마 선택은 즉시 자동 저장됩니다.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .animation(.quickEase, value: previewSurface)
        .animation(.quickEase, value: themeManager.selectedThemeID)
    }

    private var dashboardPreviewCard: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            HStack {
                Text("대시보드 미리보기")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadge(title: "대기 중", color: .secondary)
            }

            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text("새 세션 시작")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: Constants.Design.spacingSM) {
                    previewPill(title: "자유", color: themeManager.primary, isActive: true)
                    previewPill(title: "뽀모도로", color: .secondary, isActive: false)
                }

                HStack(spacing: Constants.Design.spacingSM) {
                    previewStat(title: "오늘 집중", value: "1h 20m", color: themeManager.primary)
                    previewStat(title: "완료", value: "x3", color: themeManager.secondary)
                    previewStat(title: "완료율", value: "85%", color: themeManager.accent)
                }
            }
            .padding(Constants.Design.spacingMD)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                    .stroke(themeManager.primary.opacity(0.15), lineWidth: 0.5)
            )
        }
        .padding(Constants.Design.spacingMD)
        .background(themeManager.background, in: RoundedRectangle(cornerRadius: Constants.Design.cornerLG))
    }

    private var popoverPreviewCard: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            HStack {
                Label("메뉴바 팝오버 미리보기", systemImage: "menubar.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                statusBadge(title: "차단 중", color: themeManager.primary)
            }

            Rectangle()
                .fill(.quaternary)
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text("25:00")
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(themeManager.primary)

                HStack(spacing: Constants.Design.spacingSM) {
                    previewAction(title: "일시정지", color: themeManager.pauseButton)
                    previewAction(title: "중지", color: themeManager.stopButton)
                }
            }
        }
        .padding(Constants.Design.spacingMD)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerLG))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Design.cornerLG)
                .stroke(themeManager.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func openDashboardForLivePreview() {
        openWindow(id: Constants.UI.mainDashboardWindowID)

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.UI.livePreviewArrangeDelay) {
            guard let dashboardWindow = NSApp.windows.first(where: {
                $0.title == Constants.UI.mainDashboardWindowTitle
            }) else {
                return
            }
            guard let settingsWindow = NSApp.keyWindow ?? NSApp.windows.first(where: {
                $0.title == Constants.UI.settingsWindowTitle
            }) else {
                return
            }

            alignDashboardWindow(dashboardWindow, nextTo: settingsWindow)
            dashboardWindow.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func alignDashboardWindow(_ dashboardWindow: NSWindow, nextTo settingsWindow: NSWindow) {
        guard let screen = settingsWindow.screen ?? dashboardWindow.screen ?? NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        var frame = dashboardWindow.frame
        let gap = Constants.UI.livePreviewWindowGap

        var targetX = settingsWindow.frame.maxX + gap
        if targetX + frame.width > visibleFrame.maxX {
            targetX = settingsWindow.frame.minX - frame.width - gap
        }
        targetX = min(max(targetX, visibleFrame.minX), visibleFrame.maxX - frame.width)

        var targetY = settingsWindow.frame.maxY - frame.height
        targetY = min(max(targetY, visibleFrame.minY), visibleFrame.maxY - frame.height)

        frame.origin = CGPoint(x: targetX, y: targetY)
        dashboardWindow.setFrame(frame, display: true, animate: true)
    }

    private func statusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: Capsule())
            .foregroundStyle(color)
    }

    private func previewPill(title: String, color: Color, isActive: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Constants.Design.spacingSM)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isActive ? color.opacity(0.16) : Color.secondary.opacity(0.06), in: Capsule())
            .foregroundStyle(isActive ? color : .secondary)
    }

    private func previewStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewAction(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
            .foregroundStyle(color)
    }
}

private enum PreviewSurface: String, CaseIterable, Identifiable {
    case dashboard
    case popover

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "대시보드"
        case .popover:
            return "팝오버"
        }
    }
}

#Preview {
    ThemeLivePreviewPanel()
        .environment(ThemeManager.shared)
        .frame(width: 420)
        .padding()
}
