import SwiftUI
import SwiftData
import os

// MARK: - 프로필 ViewModel (v0.5)

@MainActor
@Observable
final class ProfileViewModel {
    /// 에디터 시트 표시
    var showEditor = false

    /// 편집 중인 프로필 (nil이면 새로 생성)
    var editingProfile: BlockProfile?

    // 에디터 필드
    var editorName = ""
    var editorIcon = "shield.fill"
    var editorColor = "#E63946"
    var editorTimerMode = "free"
    var editorFocusMinutes = 25
    var editorBreakMinutes = 5
    var editorLongBreakMinutes = 15
    var editorCycles = 4

    // v1.3 고급 차단 + 취소 강도 에디터 필드
    var editorBlocklistMode = "blocklist"
    var editorCancelIntensity = 0
    var editorCancelLockoutMinutes = 5

    /// 유효성 검증 에러
    var validationError: String?

    private let logger = Logger(
        subsystem: Constants.App.subsystem,
        category: "ProfileViewModel"
    )

    // MARK: - 에디터 준비

    /// 새 프로필 생성 준비
    func prepareNewProfile() {
        editingProfile = nil
        editorName = ""
        editorIcon = "shield.fill"
        editorColor = "#E63946"
        editorTimerMode = "free"
        editorFocusMinutes = 25
        editorBreakMinutes = 5
        editorLongBreakMinutes = 15
        editorCycles = 4
        editorBlocklistMode = "blocklist"
        editorCancelIntensity = 0
        editorCancelLockoutMinutes = 5
        validationError = nil
        showEditor = true
    }

    /// 기존 프로필 편집 준비
    func prepareEdit(_ profile: BlockProfile) {
        editingProfile = profile
        editorName = profile.name
        editorIcon = profile.icon
        editorColor = profile.color
        editorTimerMode = profile.timerMode
        editorFocusMinutes = profile.focusDuration / 60
        editorBreakMinutes = profile.breakDuration / 60
        editorLongBreakMinutes = profile.longBreakDuration / 60
        editorCycles = profile.pomodoroCount
        editorBlocklistMode = profile.blocklistMode ?? "blocklist"
        editorCancelIntensity = profile.cancelIntensity ?? 0
        editorCancelLockoutMinutes = profile.cancelLockoutMinutes ?? 5
        validationError = nil
        showEditor = true
    }

    // MARK: - 저장

    func save(modelContext: ModelContext) {
        let trimmedName = editorName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            validationError = String(localized: "error_enter_profile_name")
            return
        }

        if let existing = editingProfile {
            existing.name = trimmedName
            existing.icon = editorIcon
            existing.color = editorColor
            existing.timerMode = editorTimerMode
            existing.focusDuration = editorFocusMinutes * 60
            existing.breakDuration = editorBreakMinutes * 60
            existing.longBreakDuration = editorLongBreakMinutes * 60
            existing.pomodoroCount = editorCycles
            existing.blocklistMode = editorBlocklistMode
            existing.cancelIntensity = editorCancelIntensity
            existing.cancelLockoutMinutes = editorCancelLockoutMinutes
            logger.info("프로필 수정: \(trimmedName)")
        } else {
            let profile = BlockProfile(name: trimmedName, icon: editorIcon, color: editorColor)
            profile.timerMode = editorTimerMode
            profile.focusDuration = editorFocusMinutes * 60
            profile.breakDuration = editorBreakMinutes * 60
            profile.longBreakDuration = editorLongBreakMinutes * 60
            profile.pomodoroCount = editorCycles
            profile.blocklistMode = editorBlocklistMode
            profile.cancelIntensity = editorCancelIntensity
            profile.cancelLockoutMinutes = editorCancelLockoutMinutes
            modelContext.insert(profile)
            logger.info("프로필 생성: \(trimmedName)")
        }

        showEditor = false
    }

    // MARK: - 삭제

    func delete(_ profile: BlockProfile, modelContext: ModelContext) {
        logger.info("프로필 삭제: \(profile.name)")
        modelContext.delete(profile)
    }

    /// 이름 유효성
    var isNameValid: Bool {
        !editorName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
