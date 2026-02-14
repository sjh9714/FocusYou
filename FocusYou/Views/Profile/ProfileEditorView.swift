import SwiftUI
import SwiftData

// MARK: - 프로필 에디터 (시트) (v0.5)

struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            editorHeader

            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: Constants.Design.spacingXL) {
                    nameSection
                    iconSection
                    colorSection
                    timerSection
                }
                .padding()
            }
        }
        .frame(width: 420, height: 520)
    }

    // MARK: - 헤더

    private var editorHeader: some View {
        HStack {
            Button("취소") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Spacer()

            Text(viewModel.editingProfile == nil ? "새 프로필" : "프로필 편집")
                .font(.headline)

            Spacer()

            Button("저장") {
                viewModel.save(modelContext: modelContext)
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeManager.primary)
            .fontWeight(.semibold)
            .disabled(!viewModel.isNameValid)
        }
        .padding()
    }

    // MARK: - 이름

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("프로필 이름")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                IconBadge(
                    systemName: viewModel.editorIcon,
                    color: Color(hex: viewModel.editorColor),
                    size: 36
                )

                TextField("예: 업무 집중", text: $viewModel.editorName)
                    .textFieldStyle(.plain)
                    .font(.body)
            }
            .padding(.horizontal, Constants.Design.spacingMD)
            .padding(.vertical, Constants.Design.spacingSM)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD))

            if let error = viewModel.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(themeManager.stopButton)
            }
        }
    }

    // MARK: - 아이콘 피커

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("아이콘")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 8),
                spacing: Constants.Design.spacingSM
            ) {
                ForEach(Constants.Design.profileIcons, id: \.self) { iconName in
                    let isSelected = viewModel.editorIcon == iconName

                    Button {
                        withAnimation(.quickEase) {
                            viewModel.editorIcon = iconName
                        }
                    } label: {
                        Image(systemName: iconName)
                            .font(.system(size: 16))
                            .foregroundStyle(
                                isSelected ? Color(hex: viewModel.editorColor) : .secondary
                            )
                            .frame(width: 36, height: 36)
                            .contentShape(RoundedRectangle(cornerRadius: Constants.Design.cornerSM))
                            .background(
                                isSelected
                                    ? Color(hex: viewModel.editorColor).opacity(0.12)
                                    : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Constants.Design.cornerSM)
                                    .stroke(
                                        isSelected ? Color(hex: viewModel.editorColor).opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 컬러 피커

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("색상")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 6),
                spacing: Constants.Design.spacingSM
            ) {
                ForEach(Constants.Design.profileColors, id: \.self) { hex in
                    let isSelected = viewModel.editorColor == hex

                    Button {
                        withAnimation(.quickEase) {
                            viewModel.editorColor = hex
                        }
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: isSelected ? 3 : 0)
                            )
                            .shadow(
                                color: isSelected ? Color(hex: hex).opacity(0.4) : .clear,
                                radius: 4
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 타이머 설정

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("타이머 설정")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingSM) {
                timerModeChip("자유", mode: "free")
                timerModeChip("뽀모도로", mode: "pomodoro")
                timerModeChip("플로우", mode: "flowmodoro")
            }

            VStack(spacing: Constants.Design.spacingSM) {
                timerRow(
                    icon: "bolt.fill",
                    title: "집중",
                    value: $viewModel.editorFocusMinutes,
                    range: 5...120,
                    color: Color(hex: viewModel.editorColor)
                )

                if viewModel.editorTimerMode == "pomodoro" {
                    timerRow(
                        icon: "cup.and.saucer.fill",
                        title: "짧은 휴식",
                        value: $viewModel.editorBreakMinutes,
                        range: 1...30,
                        color: themeManager.secondary
                    )
                    timerRow(
                        icon: "clock.fill",
                        title: "긴 휴식",
                        value: $viewModel.editorLongBreakMinutes,
                        range: 5...45,
                        color: themeManager.accent
                    )
                    timerRow(
                        icon: "arrow.2.squarepath",
                        title: "사이클",
                        value: $viewModel.editorCycles,
                        range: 2...8,
                        color: Color(hex: viewModel.editorColor)
                    )
                }
            }
            .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
        }
    }

    private func timerModeChip(_ title: String, mode: String) -> some View {
        ChipButton(
            title: title,
            isSelected: viewModel.editorTimerMode == mode,
            color: Color(hex: viewModel.editorColor)
        ) {
            withAnimation(.quickEase) {
                viewModel.editorTimerMode = mode
            }
        }
    }

    private func timerRow(
        icon: String,
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        color: Color
    ) -> some View {
        HStack(spacing: Constants.Design.spacingSM) {
            IconBadge(systemName: icon, color: color, size: 24)

            Text(title)
                .font(.callout)

            Spacer()

            Stepper {
                Text("\(value.wrappedValue)\(title == "사이클" ? "회" : "분")")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            } onIncrement: {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            } onDecrement: {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            }
            .fixedSize()
        }
    }
}

#Preview {
    ProfileEditorView(viewModel: ProfileViewModel())
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
