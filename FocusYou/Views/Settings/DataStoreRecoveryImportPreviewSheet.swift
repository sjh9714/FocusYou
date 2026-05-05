import SwiftUI

struct DataStoreRecoveryImportPreviewSheet: View {
    let preview: DataStoreRecoveryImportPreview
    @Binding var selectedCandidateIDs: Set<String>
    let isImporting: Bool
    let onCancel: () -> Void
    let onImport: () -> Void

    @State private var isImportConfirmationPresented = false

    var body: some View {
        let summary = preview.selectionSummary(selectedCandidateIDs: selectedCandidateIDs)

        VStack(alignment: .leading, spacing: 16) {
            Label("백업 가져오기", systemImage: "tray.and.arrow.down")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("백업: \(summary.sourceSummary)")
                    .font(.callout.weight(.medium))
                    .textSelection(.enabled)

                Text(summary.selectionSummaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(summary.canImport ? Color.secondary : Color.red)

                Text(summary.importSummaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(summary.skippedSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    selectedCandidateIDs = Set(preview.profileCandidates.map(\.id))
                } label: {
                    Label("전체 선택", systemImage: "checklist.checked")
                }
                .disabled(isImporting || selectedCandidateIDs.count == preview.profileCandidates.count)

                Button {
                    selectedCandidateIDs.removeAll()
                } label: {
                    Label("전체 해제", systemImage: "xmark.circle")
                }
                .disabled(isImporting || selectedCandidateIDs.isEmpty)

                Spacer()

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .font(.caption)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(preview.profileCandidates) { candidate in
                        Toggle(isOn: selectionBinding(for: candidate.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.displayName)
                                    .font(.callout.weight(.medium))
                                Text(candidate.detailSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .disabled(isImporting)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(minHeight: 180)

            Text("기존 데이터는 덮어쓰거나 삭제하지 않고, 선택한 설정을 새 프로필로만 추가합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("취소") {
                    onCancel()
                }
                .disabled(isImporting)

                Spacer()

                Button("선택 항목 가져오기") {
                    isImportConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!summary.canImport || isImporting)
            }
        }
        .confirmationDialog(
            "선택한 백업 설정을 가져올까요?",
            isPresented: $isImportConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("새 항목으로 가져오기") {
                onImport()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("기존 데이터는 변경하지 않고 선택 항목을 새 프로필로 추가합니다. 세션 기록과 배지는 가져오지 않습니다.")
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 420)
    }

    private func selectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: {
                selectedCandidateIDs.contains(id)
            },
            set: { isSelected in
                if isSelected {
                    selectedCandidateIDs.insert(id)
                } else {
                    selectedCandidateIDs.remove(id)
                }
            }
        )
    }
}
