import SwiftData
import XCTest
@testable import Focus_You

@MainActor
final class ProfileViewModelTests: XCTestCase {
    private var viewModel: ProfileViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ProfileViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - 새 프로필 준비

    func testPrepareNewProfileResetsFields() {
        // 먼저 필드를 변경
        viewModel.editorName = "변경됨"
        viewModel.editorIcon = "star"
        viewModel.editorColor = "#000000"

        viewModel.prepareNewProfile()

        XCTAssertNil(viewModel.editingProfile)
        XCTAssertEqual(viewModel.editorName, "")
        XCTAssertEqual(viewModel.editorIcon, "shield.fill")
        XCTAssertEqual(viewModel.editorColor, "#E63946")
        XCTAssertEqual(viewModel.editorTimerMode, "free")
        XCTAssertEqual(viewModel.editorFocusMinutes, 25)
        XCTAssertEqual(viewModel.editorBreakMinutes, 5)
        XCTAssertEqual(viewModel.editorLongBreakMinutes, 15)
        XCTAssertEqual(viewModel.editorCycles, 4)
        XCTAssertNil(viewModel.validationError)
        XCTAssertTrue(viewModel.showEditor)
    }

    // MARK: - 기존 프로필 편집 준비

    func testPrepareEditLoadsProfileData() {
        let profile = BlockProfile(name: "딥워크", icon: "brain", color: "#3B82F6")
        profile.timerMode = "pomodoro"
        profile.focusDuration = 50 * 60
        profile.breakDuration = 10 * 60
        profile.longBreakDuration = 20 * 60
        profile.pomodoroCount = 3

        viewModel.prepareEdit(profile)

        XCTAssertEqual(viewModel.editingProfile?.name, "딥워크")
        XCTAssertEqual(viewModel.editorName, "딥워크")
        XCTAssertEqual(viewModel.editorIcon, "brain")
        XCTAssertEqual(viewModel.editorColor, "#3B82F6")
        XCTAssertEqual(viewModel.editorTimerMode, "pomodoro")
        XCTAssertTrue(viewModel.showEditor)
    }

    func testPrepareEditConvertsDurationToMinutes() {
        let profile = BlockProfile(name: "테스트")
        profile.focusDuration = 1500  // 25분
        profile.breakDuration = 300   // 5분
        profile.longBreakDuration = 900  // 15분
        profile.pomodoroCount = 4

        viewModel.prepareEdit(profile)

        XCTAssertEqual(viewModel.editorFocusMinutes, 25)
        XCTAssertEqual(viewModel.editorBreakMinutes, 5)
        XCTAssertEqual(viewModel.editorLongBreakMinutes, 15)
        XCTAssertEqual(viewModel.editorCycles, 4)
    }

    // MARK: - 유효성 검증

    func testSaveEmptyNameSetsValidationError() throws {
        let context = try makeModelContext()
        viewModel.prepareNewProfile()
        viewModel.editorName = "   "

        viewModel.save(modelContext: context)

        XCTAssertNotNil(viewModel.validationError)
        XCTAssertTrue(viewModel.showEditor) // 에디터 닫히지 않음
    }

    func testIsNameValidEmpty() {
        viewModel.editorName = ""
        XCTAssertFalse(viewModel.isNameValid)
    }

    func testIsNameValidWhitespace() {
        viewModel.editorName = "   "
        XCTAssertFalse(viewModel.isNameValid)
    }

    func testIsNameValidWithText() {
        viewModel.editorName = "딥워크"
        XCTAssertTrue(viewModel.isNameValid)
    }

    // MARK: - 저장

    func testSaveNewProfileInsertsToContext() throws {
        let context = try makeModelContext()
        viewModel.prepareNewProfile()
        viewModel.editorName = "새 프로필"

        viewModel.save(modelContext: context)

        XCTAssertFalse(viewModel.showEditor)

        let descriptor = FetchDescriptor<BlockProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "새 프로필")
    }

    func testSaveExistingProfileUpdatesFields() throws {
        let context = try makeModelContext()

        // 기존 프로필 생성
        let profile = BlockProfile(name: "원래 이름")
        context.insert(profile)

        // 편집 모드 진입
        viewModel.prepareEdit(profile)
        viewModel.editorName = "변경된 이름"
        viewModel.editorIcon = "flame"
        viewModel.editorTimerMode = "pomodoro"
        viewModel.editorFocusMinutes = 50

        viewModel.save(modelContext: context)

        XCTAssertEqual(profile.name, "변경된 이름")
        XCTAssertEqual(profile.icon, "flame")
        XCTAssertEqual(profile.timerMode, "pomodoro")
        XCTAssertEqual(profile.focusDuration, 3000)  // 50 * 60
        XCTAssertFalse(viewModel.showEditor)
    }

    // MARK: - 삭제

    func testDeleteProfile() throws {
        let context = try makeModelContext()
        let profile = BlockProfile(name: "삭제 대상")
        context.insert(profile)

        viewModel.delete(profile, modelContext: context)

        let descriptor = FetchDescriptor<BlockProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertEqual(profiles.count, 0)
    }

    // MARK: - 헬퍼

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BlockProfile.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
