import SwiftUI

// MARK: - 설정 뷰 (v0.5 리디자인)

struct SettingsView: View {
    var body: some View {
        TabView {
            SettingsGeneralTabView()
                .tabItem { Label("일반", systemImage: "gearshape") }

            SettingsFocusTabView()
                .tabItem { Label("집중", systemImage: "brain.head.profile") }

            SettingsIntegrationTabView()
                .tabItem { Label("연동", systemImage: "link") }

            SettingsAdvancedTabView()
                .tabItem { Label("고급", systemImage: "wrench.and.screwdriver") }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .frame(width: 400)
}
