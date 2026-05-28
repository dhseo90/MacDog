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

    init(entry: CodexUsageEntry) {
        self.maxUsedPercent = entry.codexLimit?.maxUsedPercent ?? 0

        if let error = entry.errorMessage {
            self.statusText = "오류: \(error)"
        } else if let snapshot = entry.snapshot {
            self.statusText = snapshot.isStale(now: entry.date) ? "오래된 캐시" : "갱신됨"
        } else {
            self.statusText = "캐시 없음"
        }
    }
}

public struct CodexUsageTimelineProvider: TimelineProvider {
    private let cacheURL: URL

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
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry(date: Date) -> CodexUsageEntry {
        do {
            let snapshot = try CodexUsageCacheStore(fileURL: cacheURL).read()
            return CodexUsageEntry(date: date, snapshot: snapshot, errorMessage: snapshot.error?.message)
        } catch {
            return CodexUsageEntry(date: date, snapshot: nil, errorMessage: error.localizedDescription)
        }
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

            WidgetUsageRow(title: "5시간", window: entry.codexLimit?.fiveHour)
            WidgetUsageRow(title: "주간", window: entry.codexLimit?.weekly)
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
        }
    }

    private var summary: String {
        guard let window else { return "확인 불가" }
        return "\(percent(window.usedPercent))% 사용 / \(percent(window.remainingPercent))% 남음"
    }

    private var progress: Double {
        min(max((window?.usedPercent ?? 0) / 100, 0), 1)
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
