import CodexUsageCore
import Foundation

private func writeStatusLine(_ text: String) {
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

private func readBoundedStatusLineInput() throws -> Data {
    var input = Data()
    let maximum = ClaudeUsageCacheStore.maximumStatusLineBytes
    while input.count <= maximum {
        let remaining = maximum + 1 - input.count
        guard let chunk = try FileHandle.standardInput.read(
            upToCount: min(64 * 1_024, remaining)
        ), !chunk.isEmpty else {
            break
        }
        input.append(chunk)
    }
    return input
}

private func cacheStore(arguments: [String]) -> ClaudeUsageCacheStore? {
    guard !arguments.isEmpty else { return ClaudeUsageCacheStore() }
    guard arguments.count == 2, arguments[0] == "--test-cache-directory" else { return nil }

    let requestedDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
        .standardizedFileURL
        .resolvingSymlinksInPath()
    let allowedRoots = [
        FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath(),
        URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    ]
    let requestedPath = requestedDirectory.path.hasSuffix("/")
        ? requestedDirectory.path
        : requestedDirectory.path + "/"
    guard allowedRoots.contains(where: { root in
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return requestedPath.hasPrefix(rootPath) && requestedPath != rootPath
    }) else {
        return nil
    }

    return ClaudeUsageCacheStore(
        fileURL: requestedDirectory.appendingPathComponent("claude-usage.json"),
        historyFileURL: requestedDirectory.appendingPathComponent("claude-usage-history.json")
    )
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let store = cacheStore(arguments: arguments) else {
    writeStatusLine("Claude Preview · 설정 오류")
    exit(EXIT_SUCCESS)
}

let input: Data
do {
    input = try readBoundedStatusLineInput()
} catch {
    writeStatusLine("Claude Preview · 입력 오류")
    exit(EXIT_SUCCESS)
}

guard !input.isEmpty else {
    writeStatusLine("Claude Preview · 입력 대기")
    exit(EXIT_SUCCESS)
}

do {
    let result = try store.ingest(statusLineData: input)
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
