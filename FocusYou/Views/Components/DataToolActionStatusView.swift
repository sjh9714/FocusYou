import AppKit
import SwiftUI

struct DataToolActionStatus: Equatable, Identifiable {
    enum Action: String, Equatable {
        case backup
        case preview
        case importSettings
        case supportDiagnostics
        case copyDiagnostics

        var title: String {
            switch self {
            case .backup:
                return String(localized: "백업 만들기")
            case .preview:
                return String(localized: "백업 미리보기")
            case .importSettings:
                return String(localized: "백업 가져오기")
            case .supportDiagnostics:
                return String(localized: "진단 로그 내보내기")
            case .copyDiagnostics:
                return String(localized: "진단 정보 복사")
            }
        }

        var runningMessage: String {
            switch self {
            case .backup:
                return String(localized: "백업을 만드는 중입니다...")
            case .preview:
                return String(localized: "백업 내용을 확인하는 중입니다...")
            case .importSettings:
                return String(localized: "선택한 백업 설정을 가져오는 중입니다...")
            case .supportDiagnostics:
                return String(localized: "진단 로그를 내보내는 중입니다...")
            case .copyDiagnostics:
                return String(localized: "진단 정보를 복사하는 중입니다...")
            }
        }
    }

    enum Phase: String, Equatable {
        case running
        case success
        case failure
    }

    let action: Action
    let phase: Phase
    let message: String
    let destinationURL: URL?

    var id: String {
        [
            action.rawValue,
            phase.rawValue,
            message,
            destinationPath ?? "",
        ].joined(separator: "-")
    }

    var isRunning: Bool {
        phase == .running
    }

    var canOpenDestination: Bool {
        phase == .success && destinationURL != nil
    }

    var destinationPath: String? {
        destinationURL?.path
    }

    var iconSystemName: String {
        switch phase {
        case .running:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    var tintColor: Color {
        switch phase {
        case .running:
            return .accentColor
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

    static func running(_ action: Action) -> DataToolActionStatus {
        DataToolActionStatus(
            action: action,
            phase: .running,
            message: action.runningMessage,
            destinationURL: nil
        )
    }

    static func success(
        _ action: Action,
        message: String,
        destinationURL: URL? = nil
    ) -> DataToolActionStatus {
        DataToolActionStatus(
            action: action,
            phase: .success,
            message: message,
            destinationURL: destinationURL
        )
    }

    static func failure(
        _ action: Action,
        message: String
    ) -> DataToolActionStatus {
        DataToolActionStatus(
            action: action,
            phase: .failure,
            message: message,
            destinationURL: nil
        )
    }
}

struct DataToolActionPresentationState: Equatable {
    private(set) var status: DataToolActionStatus?

    var isRunning: Bool {
        status?.isRunning == true
    }

    mutating func begin(_ action: DataToolActionStatus.Action) -> Bool {
        guard !isRunning else {
            return false
        }

        status = .running(action)
        return true
    }

    mutating func succeed(
        _ action: DataToolActionStatus.Action,
        message: String,
        destinationURL: URL? = nil
    ) {
        status = .success(
            action,
            message: message,
            destinationURL: destinationURL
        )
    }

    mutating func fail(
        _ action: DataToolActionStatus.Action,
        message: String
    ) {
        status = .failure(action, message: message)
    }

    mutating func cancel() {
        status = nil
    }
}

struct DataToolActionStatusView: View {
    let status: DataToolActionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: status.iconSystemName)
                    .foregroundStyle(status.tintColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(status.action.title)
                        .font(.caption.weight(.medium))

                    Text(status.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                if status.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if status.canOpenDestination,
               let destinationURL = status.destinationURL {
                HStack(spacing: 12) {
                    Button {
                        copyPath(destinationURL)
                    } label: {
                        Label("경로 복사", systemImage: "doc.on.doc")
                    }

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                    } label: {
                        Label("Finder에서 보기", systemImage: "folder")
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
            }
        }
    }

    private func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }
}
