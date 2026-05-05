import SwiftUI

struct DataStoreRecoveryImportPreviewSheet: View {
    let preview: DataStoreRecoveryImportPreview
    @Binding var selectedCandidateIDs: Set<String>
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("백업 가져오기", systemImage: "tray.and.arrow.down")
                .font(.title3.bold())

            Text(preview.statusSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(minHeight: 180)

            Text("세션 기록과 배지는 이번 가져오기에서 복사하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("취소") {
                    onCancel()
                }

                Spacer()

                Button("선택 항목 가져오기") {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCandidateIDs.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 380)
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
