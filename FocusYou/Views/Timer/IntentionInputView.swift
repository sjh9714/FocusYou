import SwiftUI
import SwiftData

// MARK: - 의도 입력 뷰 (v1.1)
// IdleContentView 내부에서 조건부 표시

struct IntentionInputView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var intentionText: String
    let recentIntentions: [String]
    let onStart: (String?) -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: Constants.Design.spacingLG) {
            header
            textField
            suggestions
            actionButtons
        }
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(spacing: Constants.Design.spacingXS) {
            Image(systemName: "target")
                .font(.system(size: 28))
                .foregroundStyle(themeManager.primary)

            Text("이번 세션의 의도")
                .font(.headline)

            Text("무엇에 집중할까요?")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 텍스트 입력

    private var textField: some View {
        TextField("예: 보고서 작성, 코드 리뷰...", text: $intentionText)
            .textFieldStyle(.plain)
            .font(.callout)
            .padding(Constants.Design.spacingMD)
            .background(
                Color.secondary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Design.cornerMD)
                    .stroke(
                        isTextFieldFocused ? themeManager.primary.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
            .focused($isTextFieldFocused)
            .onSubmit {
                let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
                onStart(trimmed.isEmpty ? nil : trimmed)
            }
            .onAppear {
                isTextFieldFocused = true
            }
    }

    // MARK: - 최근 의도 추천

    @ViewBuilder
    private var suggestions: some View {
        if !recentIntentions.isEmpty {
            VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
                Text("최근 의도")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.Design.spacingSM) {
                        ForEach(recentIntentions, id: \.self) { intention in
                            Button {
                                intentionText = intention
                            } label: {
                                Text(intention)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        themeManager.primary.opacity(0.08),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(themeManager.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 액션 버튼

    private var actionButtons: some View {
        Button {
            let trimmed = intentionText.trimmingCharacters(in: .whitespacesAndNewlines)
            onStart(trimmed.isEmpty ? nil : trimmed)
        } label: {
            Label("집중 시작", systemImage: "bolt.fill")
        }
        .primaryActionStyle(color: themeManager.startButton)
    }
}

#Preview {
    IntentionInputView(
        intentionText: .constant(""),
        recentIntentions: ["보고서 작성", "코드 리뷰", "디자인 검토"],
        onStart: { _ in }
    )
    .environment(ThemeManager.shared)
    .frame(width: 340)
    .padding()
}
