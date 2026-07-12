import CodexUsageCore
import Foundation

private func writeStatusLine(_ text: String, existingOutput: Data? = nil) {
    if let existingOutput, !existingOutput.isEmpty {
        FileHandle.standardOutput.write(existingOutput)
        if existingOutput.last != 0x0A {
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }
    FileHandle.standardOutput.write(Data((text + "\n").utf8))
}

private func existingStatusLineOutput(input: Data) -> Data? {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2,
          arguments[0] == "--existing-command",
          !arguments[1].isEmpty,
          arguments[1].utf8.count <= 4_096 else {
        return nil
    }
    let process = Process()
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", arguments[1]]
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        inputPipe.fileHandleForWriting.write(input)
        try inputPipe.fileHandleForWriting.close()
        let output = try outputPipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        return output
    } catch {
        return nil
    }
}

guard let input = try? FileHandle.standardInput.read(
    upToCount: ClaudeUsageCacheStore.maximumStatusLineBytes + 1
), !input.isEmpty else {
    writeStatusLine("Claude Preview · 입력 대기")
    exit(EXIT_SUCCESS)
}
let existingOutput = existingStatusLineOutput(input: input)

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
        writeStatusLine(
            values.isEmpty ? "Claude Preview · 사용량 대기" : "Claude · " + values.joined(separator: " · "),
            existingOutput: existingOutput
        )
    case .failed:
        writeStatusLine("Claude Preview · 입력 오류", existingOutput: existingOutput)
    }
} catch {
    writeStatusLine("Claude Preview · 저장 오류", existingOutput: existingOutput)
}
