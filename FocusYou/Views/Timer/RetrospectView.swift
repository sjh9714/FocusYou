import SwiftUI
import os

private let logger = Logger(subsystem: Constants.App.subsystem, category: "Retrospect")

// MARK: - 회고 뷰 (v1.5 3-레벨 지원)
// Level 1: 이모지 4개 선택
// Level 2: 이모지 + 텍스트 한 줄
// Level 3: 텍스트 + 별점(1-5) + 방해요소 태그

struct RetrospectView: View {
    @Environment(ThemeManager.self) private var themeManager
    let level: Int
    let onComplete: (RetrospectData) -> Void
    let onSkip: () -> Void

    @State private var selectedEmoji: String?
    @State private var memoText = ""
    @State private var starRating = 0
    @State private var selectedTags: Set<String> = []
    @State private var isSubmitted = false

    var body: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            Text("이번 세션은 어땠나요?")
                .font(.callout.weight(.medium))

            switch level {
            case 2: level2Content
            case 3: level3Content
            default: level1Content
            }

            skipButton
        }
        .frostedCard(cornerRadius: Constants.Design.cornerMD, padding: Constants.Design.spacingMD)
    }

    // MARK: - Level 1: 이모지만

    private var level1Content: some View {
        emojiButtons
    }

    // MARK: - Level 2: 이모지 + 텍스트

    private var level2Content: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            emojiButtons

            if selectedEmoji != nil {
                memoField

                submitButton {
                    submit(emoji: selectedEmoji, text: memoText.nonEmpty)
                }
            }
        }
        .animation(.focusSpring, value: selectedEmoji)
    }

    // MARK: - Level 3: 텍스트 + 별점 + 태그

    private var level3Content: some View {
        VStack(spacing: Constants.Design.spacingMD) {
            // 별점
            VStack(spacing: Constants.Design.spacingXS) {
                Text("만족도")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StarRatingView(rating: $starRating)
            }

            memoField

            // 방해요소
            VStack(alignment: .leading, spacing: Constants.Design.spacingXS) {
                Text("방해 요소")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DisruptionTagPicker(selectedTags: $selectedTags)
            }

            submitButton {
                let tagsString = selectedTags.isEmpty ? nil : selectedTags.sorted().joined(separator: ",")
                submit(emoji: tagsString, text: memoText.nonEmpty, rating: starRating > 0 ? starRating : nil)
            }
        }
    }
}

// MARK: - 공통 서브뷰

private extension RetrospectView {

    var emojiButtons: some View {
        HStack(spacing: Constants.Design.spacingLG) {
            ForEach(Self.emojiOptions, id: \.emoji) { option in
                Button {
                    guard selectedEmoji == nil else { return }
                    withAnimation(.focusSpring) {
                        selectedEmoji = option.emoji
                    }
                    // Level 1은 이모지 선택 즉시 완료
                    if level == 1 {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            submit(emoji: option.emoji)
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(option.emoji)
                            .font(.system(size: 28))
                        Text(option.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .scaleEffect(selectedEmoji == option.emoji ? 1.2 : 1.0)
                    .opacity(selectedEmoji == nil || selectedEmoji == option.emoji ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(selectedEmoji != nil)
                .accessibilityLabel("\(option.label) 회고")
            }
        }
    }

    var memoField: some View {
        TextField("어떤 작업을 했나요?", text: $memoText)
            .textFieldStyle(.roundedBorder)
    }

    func submitButton(action: @escaping () -> Void) -> some View {
        Button {
            guard !isSubmitted else { return }
            action()
        } label: {
            Text("완료")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Constants.Design.spacingSM)
                .background(themeManager.primary, in: RoundedRectangle(cornerRadius: Constants.Design.cornerSM))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitted)
        .opacity(isSubmitted ? 0.5 : 1.0)
    }

    @ViewBuilder
    var skipButton: some View {
        if !isSubmitted {
            Button {
                onSkip()
            } label: {
                Text("건너뛰기")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    func submit(emoji: String? = nil, text: String? = nil, rating: Int? = nil) {
        isSubmitted = true
        let data = RetrospectData(emoji: emoji, text: text, rating: rating)
        onComplete(data)
    }

    static let emojiOptions: [(emoji: String, label: String)] = [
        ("😊", "좋았어"),
        ("😐", "보통"),
        ("😫", "힘들었어"),
        ("🔥", "몰입!"),
    ]
}

// MARK: - 회고 데이터

struct RetrospectData {
    var emoji: String?
    var text: String?
    var rating: Int?
}

// MARK: - String 확장

private extension String {
    /// 빈 문자열이면 nil 반환
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

#Preview("Level 1") {
    RetrospectView(
        level: 1,
        onComplete: { data in logger.debug("Complete: \(String(describing: data))") },
        onSkip: { logger.debug("Skipped") }
    )
    .environment(ThemeManager.shared)
    .frame(width: 340)
    .padding()
}

#Preview("Level 2") {
    RetrospectView(
        level: 2,
        onComplete: { data in logger.debug("Complete: \(String(describing: data))") },
        onSkip: { logger.debug("Skipped") }
    )
    .environment(ThemeManager.shared)
    .frame(width: 340)
    .padding()
}

#Preview("Level 3") {
    RetrospectView(
        level: 3,
        onComplete: { data in logger.debug("Complete: \(String(describing: data))") },
        onSkip: { logger.debug("Skipped") }
    )
    .environment(ThemeManager.shared)
    .frame(width: 340)
    .padding()
}
