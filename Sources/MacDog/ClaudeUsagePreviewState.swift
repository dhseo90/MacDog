import CodexUsageCore
import Foundation

enum UsagePreviewProvider: String, CaseIterable, Identifiable {
    case codex
    case claude

    var id: String { rawValue }

    var label: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude Preview"
        }
    }
}

struct ClaudeUsagePreviewState: Equatable {
    static let disabled = ClaudeUsagePreviewState(
        isEnabled: false,
        cacheSnapshot: nil,
        history: .empty,
        loadIssue: nil
    )

    let isEnabled: Bool
    let cacheSnapshot: ClaudeUsageCacheSnapshot?
    let history: ClaudeUsageHistory
    let loadIssue: String?

    var usage: ClaudeStatusLineSnapshot? { cacheSnapshot?.usage }

    func status(now: Date = Date()) -> ClaudeUsageCacheStatus {
        guard isEnabled else { return .waiting }
        if loadIssue != nil { return .error }
        return cacheSnapshot?.status(now: now) ?? .waiting
    }

    func runnerUsedPercent(now: Date = Date()) -> Double? {
        guard isEnabled else { return nil }
        return cacheSnapshot?.freshMaxUsedPercent(now: now)
    }

    var statusTitle: String {
        if !isEnabled { return "Preview 꺼짐" }
        if loadIssue != nil { return "cache 확인 필요" }
        switch cacheSnapshot?.status() ?? .waiting {
        case .waiting: return "연결 대기"
        case .partial: return "일부 window 수신"
        case .available: return "Preview 데이터 정상"
        case .stale: return "오래된 event"
        case .error: return "sanitize bridge 오류"
        }
    }
}

enum ClaudeStatusLineConnectionState: Equatable {
    case previewDisabled
    case manualReviewRequired

    var title: String {
        switch self {
        case .previewDisabled: "연결하지 않음"
        case .manualReviewRequired: "수동 연결 검토 필요"
        }
    }
}

struct ClaudeStatusLineConnectionGuide: Equatable {
    let bridgePath: String

    var standaloneCommand: String {
        "\"\(bridgePath)\""
    }

    var mergeCommandPreview: String {
        "\"\(bridgePath)\" --existing-command '<기존 statusLine command>'"
    }

    static var bundled: ClaudeStatusLineConnectionGuide {
        let path = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("macdog-claude-statusline")
            .path ?? "/Applications/MacDog.app/Contents/MacOS/macdog-claude-statusline"
        return ClaudeStatusLineConnectionGuide(bridgePath: path)
    }
}
