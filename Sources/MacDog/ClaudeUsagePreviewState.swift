import CodexUsageCore
import Foundation

enum UsageProviderMode: String, CaseIterable, Identifiable {
    case codex
    case grok
    case claude

    var id: String { rawValue }

    var label: String {
        switch self {
        case .codex: "Codex"
        case .grok: "Grok"
        case .claude: "Claude"
        }
    }

    var isVisibleInSettings: Bool {
        switch self {
        case .codex, .grok:
            true
        case .claude:
            false
        }
    }

    static var visibleCases: [UsageProviderMode] {
        allCases.filter(\.isVisibleInSettings)
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

    func currentWindow(
        _ kind: ClaudeUsageWindowKind,
        now: Date = Date()
    ) -> ClaudeUsageWindowSnapshot? {
        guard isEnabled else { return nil }
        return cacheSnapshot?.freshWindow(kind, now: now)
    }

    func statusTitle(now: Date = Date()) -> String {
        if !isEnabled { return "연결 대기" }
        if loadIssue != nil { return "cache 확인 필요" }
        switch cacheSnapshot?.status(now: now) ?? .waiting {
        case .waiting: return "연결 대기"
        case .partial: return "일부 window 수신"
        case .available: return "데이터 정상"
        case .stale: return "오래된 event"
        case .error: return "sanitize bridge 오류"
        }
    }
}

struct ClaudeStatusLineConnectionGuide: Equatable {
    let bridgePath: String

    var standaloneCommand: String {
        "\"\(bridgePath)\""
    }

    static var bundled: ClaudeStatusLineConnectionGuide {
        let path = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("macdog-claude-statusline")
            .path ?? "/Applications/MacDog.app/Contents/MacOS/macdog-claude-statusline"
        return ClaudeStatusLineConnectionGuide(bridgePath: path)
    }
}
