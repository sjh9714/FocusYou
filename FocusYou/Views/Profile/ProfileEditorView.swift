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
            editorHeader

            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: Constants.Design.spacingXL) {
                    nameSection
                    ProfileEditorFormSections(viewModel: viewModel)
                }
                .padding()
            }
        }
        .frame(width: 420, height: 600)
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
}

#Preview {
    ProfileEditorView(viewModel: ProfileViewModel())
        .environment(ThemeManager.shared)
        .environment(LicenseManager.shared)
        .modelContainer(for: [
            BlockedSite.self, BlockedApp.self,
            BlockProfile.self, FocusSession.self,
        ], inMemory: true)
}
