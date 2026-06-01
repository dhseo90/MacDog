import CodexUsageCore
import SwiftUI
import WidgetKit

public struct MacDogWidgetBundle: WidgetBundle {
    private let appGroupIdentifier: String?

    public init() {
        self.appGroupIdentifier = nil
    }

    public init(appGroupIdentifier: String?) {
        self.appGroupIdentifier = appGroupIdentifier
    }

    public var body: some Widget {
        MacDogStatusWidget(appGroupIdentifier: appGroupIdentifier)
    }
}

public enum MacDogWidgetDeepLink {
    public static let openURL = URL(string: "macdog://open")!
}

public struct MacDogStatusWidget: Widget {
    public let kind = "MacDogStatusWidget"
    private let provider: CodexUsageTimelineProvider

    public init() {
        self.provider = CodexUsageTimelineProvider()
    }

    public init(appGroupIdentifier: String?) {
        self.provider = CodexUsageTimelineProvider(appGroupIdentifier: appGroupIdentifier)
    }

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: provider) { entry in
            MacDogUsageWidgetView(entry: entry)
                .widgetURL(MacDogWidgetDeepLink.openURL)
        }
        .configurationDisplayName("MacDog")
        .description("공유 캐시의 Codex 5시간/주간 사용량을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct CodexUsageEntry: TimelineEntry {
    public let date: Date
    public let snapshot: CodexUsageCacheSnapshot?
    public let errorMessage: String?

    public init(date: Date, snapshot: CodexUsageCacheSnapshot?, errorMessage: String?) {
        self.date = date
        self.snapshot = snapshot
        self.errorMessage = errorMessage
    }

    public var report: CodexUsageReport? {
        snapshot?.report
    }

    public var codexLimit: UsageLimitReport? {
        report?.codexLimit
    }
}


struct WidgetUsagePresentation: Equatable {
    let maxUsedPercent: Double
    let statusText: String
    let resetText: String
    let metadataText: String

    init(entry: CodexUsageEntry) {
        self.maxUsedPercent = entry.codexLimit?.maxUsedPercent ?? 0
        if let highestWindow = Self.highestUsageWindow(from: entry.codexLimit) {
            self.resetText = Self.resetText(label: highestWindow.label, window: highestWindow.window, now: entry.date)
        } else {
            self.resetText = "초기화 시각 알 수 없음"
        }

        if let error = entry.errorMessage {
            self.statusText = "오류: \(error)"
        } else if let snapshot = entry.snapshot {
            self.statusText = snapshot.isStale(now: entry.date) ? "오래된 캐시" : "갱신됨"
        } else {
            self.statusText = "캐시 없음"
        }

        self.metadataText = Self.metadataText(
            report: entry.report,
            cachedAt: entry.snapshot?.cachedAt,
            now: entry.date
        )
    }

    static func resetText(label: String?, window: UsageWindowReport?, now: Date) -> String {
        let prefix = label.map { "\($0) " } ?? ""
        guard let window else { return "\(prefix)확인 불가" }
        guard let resetsAt = window.resetsAt else { return "\(prefix)초기화 시각 알 수 없음" }

        let resetDate = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        let remaining = resetRemainingSummary(until: resetDate, now: now)
        if remaining == "초기화 확인 중" {
            return "\(prefix)\(remaining)"
        }
        return "\(prefix)초기화까지 \(remaining)"
    }

    private static func highestUsageWindow(from limit: UsageLimitReport?) -> (label: String, window: UsageWindowReport)? {
        guard let limit else { return nil }

        let windows: [(String, UsageWindowReport)] = [
            ("5시간", limit.fiveHour),
            ("주간", limit.weekly)
        ].compactMap { label, window in
            guard let window else { return nil }
            return (label, window)
        }

        return windows.max { $0.1.usedPercent < $1.1.usedPercent }
    }

    private static func resetRemainingSummary(until resetDate: Date, now: Date) -> String {
        let seconds = Int(ceil(resetDate.timeIntervalSince(now)))
        guard seconds > 0 else { return "초기화 확인 중" }
        guard seconds >= 60 else { return "1분 미만 남음" }

        let minutes = Int(ceil(Double(seconds) / 60))
        guard minutes >= 60 else { return "\(minutes)분 남음" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        guard hours >= 24 else {
            if remainingMinutes == 0 {
                return "\(hours)시간 남음"
            }
            return "\(hours)시간 \(remainingMinutes)분 남음"
        }

        let days = hours / 24
        let remainingHours = hours % 24
        if remainingHours == 0 {
            return "\(days)일 남음"
        }
        return "\(days)일 \(remainingHours)시간 남음"
    }

    static func metadataText(report: CodexUsageReport?, cachedAt: Int?, now: Date) -> String {
        let credits = creditsText(report?.codexLimit?.credits ?? report?.credits)
        let updated = lastUpdatedText(cachedAt: cachedAt, now: now)
        return "\(credits) · \(updated)"
    }

    private static func creditsText(_ credits: CreditsSnapshot?) -> String {
        guard let credits else { return "크레딧 알 수 없음" }
        if credits.unlimited {
            return "크레딧 무제한"
        }
        return "크레딧 \(credits.balance ?? "알 수 없음")"
    }

    private static func lastUpdatedText(cachedAt: Int?, now: Date) -> String {
        guard let cachedAt else { return "갱신 알 수 없음" }
        let cachedDate = Date(timeIntervalSince1970: TimeInterval(cachedAt))
        let seconds = max(Int(now.timeIntervalSince(cachedDate)), 0)
        if seconds < 60 {
            return "갱신 방금"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "갱신 \(minutes)분 전"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "갱신 \(hours)시간 전"
        }

        return "갱신 \(hours / 24)일 전"
    }
}

public struct CodexUsageTimelineProvider: TimelineProvider {
    private let cacheURL: URL
    private static let missingFilePOSIXCode = Int(POSIXErrorCode.ENOENT.rawValue)

    public init(cacheURL: URL = CodexUsageCacheStore.defaultFileURL()) {
        self.cacheURL = cacheURL
    }

    public init(appGroupIdentifier: String?) {
        self.cacheURL = CodexUsageCacheStore.defaultFileURL(appGroupIdentifier: appGroupIdentifier)
    }

    public func placeholder(in context: Context) -> CodexUsageEntry {
        CodexUsageEntry(date: Date(), snapshot: Self.placeholderSnapshot, errorMessage: nil)
    }

    public func getSnapshot(in context: Context, completion: @escaping (CodexUsageEntry) -> Void) {
        completion(loadEntry(date: Date()))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<CodexUsageEntry>) -> Void) {
        let now = Date()
        let entry = loadEntry(date: now)
        let refresh = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now.addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry(date: Date) -> CodexUsageEntry {
        do {
            let snapshot = try CodexUsageCacheStore(fileURL: cacheURL).read()
            return CodexUsageEntry(date: date, snapshot: snapshot, errorMessage: snapshot.error?.message)
        } catch {
            if Self.isMissingCacheError(error) {
                return CodexUsageEntry(date: date, snapshot: nil, errorMessage: nil)
            }
            return CodexUsageEntry(date: date, snapshot: nil, errorMessage: "캐시를 읽을 수 없음")
        }
    }

    static func isMissingCacheError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileReadNoSuchFile.rawValue {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == missingFilePOSIXCode {
            return true
        }

        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        return underlying?.domain == NSPOSIXErrorDomain && underlying?.code == missingFilePOSIXCode
    }

    private static var placeholderSnapshot: CodexUsageCacheSnapshot {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 24,
            remainingPercent: 76,
            windowDurationMins: 300,
            resetsAt: nil
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: 40,
            remainingPercent: 60,
            windowDurationMins: 10_080,
            resetsAt: nil
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: nil,
            primary: fiveHour,
            secondary: weekly,
            credits: CreditsSnapshot(hasCredits: false, unlimited: false, balance: "0"),
            planType: "pro",
            rateLimitReachedType: nil
        )
        let report = CodexUsageReport(
            generatedAt: Int(Date().timeIntervalSince1970),
            source: "placeholder",
            planType: "pro",
            credits: limit.credits,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
        return CodexUsageCacheSnapshot(
            cachedAt: report.generatedAt,
            staleAfterSeconds: CodexUsageCacheStore.defaultStaleAfterSeconds,
            report: report,
            error: nil
        )
    }
}

public struct MacDogUsageWidgetView: View {
    @Environment(\.widgetFamily) private var family

    public let entry: CodexUsageEntry

    public init(entry: CodexUsageEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Codex")
                .font(.headline)

            Text("\(percent(maxUsedPercent))% 사용 중")
                .font(.title2.bold())
                .foregroundStyle(phaseColor)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(presentation.resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .containerBackground(.background, for: .widget)
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MacDog")
                    .font(.headline)
                Spacer()
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(presentation.metadataText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            WidgetUsageRow(title: "5시간", window: entry.codexLimit?.fiveHour, date: entry.date)
            WidgetUsageRow(title: "주간", window: entry.codexLimit?.weekly, date: entry.date)
        }
        .containerBackground(.background, for: .widget)
    }

    private var presentation: WidgetUsagePresentation {
        WidgetUsagePresentation(entry: entry)
    }

    private var maxUsedPercent: Double {
        presentation.maxUsedPercent
    }

    private var statusText: String {
        presentation.statusText
    }

    private var phaseColor: Color {
        switch maxUsedPercent {
        case 95...:
            .red
        case 80..<95:
            .orange
        case 50..<80:
            .accentColor
        default:
            .secondary
        }
    }

    private func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

private struct WidgetUsageRow: View {
    let title: String
    let window: UsageWindowReport?
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(tint)
            Text(resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var summary: String {
        guard let window else { return "확인 불가" }
        return "\(percent(window.usedPercent))% 사용 / \(percent(window.remainingPercent))% 남음"
    }

    private var progress: Double {
        min(max((window?.usedPercent ?? 0) / 100, 0), 1)
    }

    private var resetText: String {
        WidgetUsagePresentation.resetText(label: nil, window: window, now: date)
    }

    private var tint: Color {
        switch window?.usedPercent ?? 0 {
        case 95...:
            .red
        case 80..<95:
            .orange
        case 50..<80:
            .accentColor
        default:
            .secondary
        }
    }

    private func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
