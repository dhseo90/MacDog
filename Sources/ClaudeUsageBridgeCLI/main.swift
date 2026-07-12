import CodexUsageCore
import Foundation

private func writeStatusLine(_ text: String) {
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

guard let input = try? FileHandle.standardInput.read(
    upToCount: ClaudeUsageCacheStore.maximumStatusLineBytes + 1
), !input.isEmpty else {
    writeStatusLine("Claude Preview · 입력 대기")
    exit(EXIT_SUCCESS)
}

do {
    let environment = ProcessInfo.processInfo.environment
    let cacheURL = environment["MACDOG_CLAUDE_CACHE_PATH"].map {
        URL(fileURLWithPath: $0)
    } ?? ClaudeUsageCacheStore.defaultFileURL()
    let historyURL = environment["MACDOG_CLAUDE_HISTORY_PATH"].map {
        URL(fileURLWithPath: $0)
    }
    let result = try ClaudeUsageCacheStore(
        fileURL: cacheURL,
        historyFileURL: historyURL
    ).ingest(statusLineData: input)
    switch result {
    case .stored(let snapshot):
        let values: [String] = [
            snapshot.fiveHour?.usedPercent.map { "5시간 \(Int($0.rounded()))%" },
            snapshot.sevenDay?.usedPercent.map { "7일 \(Int($0.rounded()))%" }
        ].compactMap(\.self)
        writeStatusLine(values.isEmpty ? "Claude Preview · 사용량 대기" : "Claude · " + values.joined(separator: " · "))
    case .failed:
        writeStatusLine("Claude Preview · 입력 오류")
    }
} catch {
    writeStatusLine("Claude Preview · 저장 오류")
}
