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

    var petTitle: String { "\(label) 펫" }
    var quitUsageTitle: String { "\(label) 사용량 종료" }
    var runningTriggerTitle: String { "\(label) 실행 중" }
    var runningTriggerSummary: String { "\(label) 실행" }
    var runningAppModeLabel: String { "\(label) 앱 실행 중" }

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

enum SelectedUsageSourcePolicy {
    static func shouldEvaluateCodexCache(for mode: UsageProviderMode) -> Bool {
        mode == .codex
    }

    static func shouldLoadClaudePreview(for mode: UsageProviderMode) -> Bool {
        mode == .claude
    }

    static func shouldLoadGrokCache(for mode: UsageProviderMode) -> Bool {
        mode == .grok
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

struct GrokUsagePreviewState: Equatable {
    static let disabled = GrokUsagePreviewState(
        isEnabled: false,
        cacheSnapshot: nil,
        history: .empty,
        loadIssue: nil
    )

    let isEnabled: Bool
    let cacheSnapshot: GrokUsageCacheSnapshot?
    let history: GrokUsageHistory
    let loadIssue: String?

    func status(now: Date = Date()) -> GrokUsageCacheStatus {
        guard isEnabled else { return .waiting }
        if loadIssue != nil { return .error }
        return cacheSnapshot?.status(now: now) ?? .waiting
    }

    func runnerUsedPercent(now: Date = Date()) -> Double? {
        guard isEnabled else { return nil }
        return cacheSnapshot?.freshWeekly(now: now)?.usedPercent
    }

    func statusTitle(now: Date = Date()) -> String {
        if !isEnabled { return "연결 대기" }
        if loadIssue != nil { return "cache 확인 필요" }
        switch emptyStateKind {
        case .loginRequired:
            return "로그인 필요"
        case .sessionRefreshFailed:
            return "세션 갱신 실패"
        case .lookupFailed:
            return "조회 오류"
        case .weeklyWindowMissing:
            return "주간 window 없음"
        case .waiting, .cacheLoadFailed:
            break
        }
        switch cacheSnapshot?.status(now: now) ?? .waiting {
        case .waiting: return "연결 대기"
        case .available: return "데이터 정상"
        case .stale: return "오래된 cache"
        case .error: return "조회 오류"
        }
    }

    var issueCode: String? { cacheSnapshot?.issue?.code }

    var needsLoginGuidance: Bool {
        emptyStateKind == .loginRequired
    }

    var showsLoginActions: Bool {
        switch emptyStateKind {
        case .loginRequired, .sessionRefreshFailed, .waiting:
            return true
        case .lookupFailed, .weeklyWindowMissing, .cacheLoadFailed:
            return false
        }
    }

    func weeklyCardUnavailableText() -> String? {
        switch emptyStateKind {
        case .loginRequired:
            return "로그인 필요"
        case .sessionRefreshFailed:
            return "세션 갱신 실패"
        case .lookupFailed:
            return "조회 오류"
        case .weeklyWindowMissing:
            return "주간 window 없음"
        case .cacheLoadFailed, .waiting:
            return nil
        }
    }

    func emptyStateTitle() -> String {
        switch emptyStateKind {
        case .cacheLoadFailed:
            return "Grok cache 확인 필요"
        case .loginRequired:
            return "Grok 로그인 필요"
        case .sessionRefreshFailed:
            return "Grok 세션 갱신 실패"
        case .lookupFailed:
            return "Grok 조회 오류"
        case .weeklyWindowMissing:
            return "Grok 주간 window 없음"
        case .waiting:
            return "Grok 주간 cache 없음"
        }
    }

    func emptyStateDetail() -> String {
        switch emptyStateKind {
        case .cacheLoadFailed:
            return loadIssue ?? "Grok cache를 읽지 못했습니다."
        case .loginRequired:
            return "Grok 주간 사용량은 grok.com 로그인이 필요합니다. 터미널에서 grok login을 실행한 뒤 잠시 기다리세요. 메뉴바는 auth.json을 읽지 않고 Codex cache로 대체하지 않습니다."
        case .sessionRefreshFailed:
            return "Grok 세션을 갱신하지 못했습니다. 잠시 후 다시 조회합니다. 반복되면 터미널에서 grok login을 실행하세요. Codex cache로 대체하지 않습니다."
        case .lookupFailed:
            return "Grok 주간 사용량 조회에 실패했습니다. 네트워크나 billing 응답을 확인하세요. 지금은 grok login이 필요한 상태가 아닙니다. Codex cache로 대체하지 않습니다."
        case .weeklyWindowMissing:
            return "주간 사용량 window를 읽지 못했습니다. 로그인과 별개입니다. Codex cache로 대체하지 않습니다."
        case .waiting:
            return "첫 주간 sample이 생기면 사용량이 표시됩니다. grok.com에 로그인되어 있지 않으면 터미널에서 grok login을 실행하세요. Codex cache로 대체하지 않습니다."
        }
    }

    private var emptyStateKind: GrokEmptyStateKind {
        guard isEnabled else { return .waiting }
        if loadIssue != nil { return .cacheLoadFailed }
        switch issueCode {
        case "auth-unavailable":
            return .loginRequired
        case "auth-expired", "auth-refresh-failed":
            return .sessionRefreshFailed
        case "request-failed":
            return .lookupFailed
        case "weekly-window-missing":
            return .weeklyWindowMissing
        default:
            break
        }
        if cacheSnapshot?.weekly == nil {
            return .loginRequired
        }
        return .waiting
    }
}

private enum GrokEmptyStateKind: Equatable {
    case loginRequired
    case sessionRefreshFailed
    case lookupFailed
    case weeklyWindowMissing
    case cacheLoadFailed
    case waiting
}

struct GrokLoginGuide: Equatable {
    static let command = "grok login"

    var standaloneCommand: String { Self.command }

    var terminalCommand: String {
        #"export PATH="$HOME/.grok/bin:$PATH"; grok login"#
    }

    func appleScriptSource() -> String {
        let escaped = terminalCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
    }

    func openTerminal(
        runner: (URL, [String]) throws -> Void = { executable, arguments in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            try process.run()
        }
    ) throws {
        try runner(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            ["-e", appleScriptSource()]
        )
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
