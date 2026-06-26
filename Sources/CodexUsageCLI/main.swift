import CodexUsageCore
import Foundation

enum ExitCode: Int32 {
    case success = 0
    case usage = 2
    case failure = 1
}

struct CLI {
    let arguments: [String]
    let output: (String) -> Void
    let errorOutput: (String) -> Void

    func run() -> ExitCode {
        let command = arguments.dropFirst().first ?? "status"

        switch command {
        case "status":
            return runStatus(Array(arguments.dropFirst().dropFirst()))
        case "doctor":
            return runDoctor()
        case "-h", "--help", "help":
            output(Self.help)
            return .success
        default:
            errorOutput("Unknown command: \(command)\n\n\(Self.help)")
            return .usage
        }
    }

    private func runStatus(_ args: [String]) -> ExitCode {
        var json = false
        var watchInterval: UInt32?
        var writeCache = false
        var mirrorCache = false
        var cachePath: String?
        var timeout: TimeInterval?
        var index = 0

        while index < args.count {
            switch args[index] {
            case "--json":
                json = true
            case "--write-cache":
                writeCache = true
            case "--mirror-cache":
                mirrorCache = true
            case "--cache-path":
                guard index + 1 < args.count else {
                    errorOutput("--cache-path requires a file path.")
                    return .usage
                }
                cachePath = args[index + 1]
                index += 1
            case "--timeout":
                guard index + 1 < args.count,
                      let value = TimeInterval(args[index + 1]),
                      value > 0
                else {
                    errorOutput("--timeout requires a positive number of seconds.")
                    return .usage
                }
                timeout = value
                index += 1
            case "--watch":
                guard index + 1 < args.count, let interval = UInt32(args[index + 1]), interval > 0 else {
                    errorOutput("--watch requires a positive interval in seconds.")
                    return .usage
                }
                watchInterval = interval
                index += 1
            default:
                errorOutput("Unknown status option: \(args[index])")
                return .usage
            }
            index += 1
        }

        repeat {
            let exitCode = printStatus(
                json: json,
                writeCache: writeCache,
                mirrorCache: mirrorCache,
                cachePath: cachePath,
                timeout: timeout
            )
            if watchInterval == nil {
                return exitCode
            }
            sleep(watchInterval!)
        } while true
    }

    private func printStatus(
        json: Bool,
        writeCache: Bool,
        mirrorCache: Bool,
        cachePath: String?,
        timeout: TimeInterval?
    ) -> ExitCode {
        let cacheStores = makeCacheStores(path: cachePath, mirrorCache: mirrorCache)

        do {
            let formatter = CodexUsageFormatter()
            let report = try makeService(timeout: timeout).readReport()
            var cacheWriteResults: [CodexUsageCacheWriteResult] = []

            if writeCache {
                cacheWriteResults = try cacheStores.map { try $0.writeSuccess(report: report) }
            }

            if json {
                let data = try formatter.json(from: report)
                output(String(decoding: data, as: UTF8.self))
            } else {
                output(formatter.text(from: report))
            }
            if writeCache {
                let diagnosticFormatter = CodexUsageCacheWriteDiagnosticFormatter()
                cacheWriteResults
                    .map { diagnosticFormatter.line(from: $0) }
                    .forEach(errorOutput)
            }
            return .success
        } catch {
            if writeCache {
                cacheStores.forEach { try? $0.writeFailure(message: error.localizedDescription) }
            }
            errorOutput(CodexUsageFailureGuide().message(for: error, context: .status))
            return .failure
        }
    }

    private func runDoctor() -> ExitCode {
        output("Codex Usage Doctor")

        do {
            let resolver = CodexCLIResolver()
            let codexURL = try resolver.resolve()
            output("Codex CLI: \(codexURL.path)")

            let service = CodexUsageService(client: CodexAppServerClient(codexURL: codexURL))
            let diagnostic = try service.readDiagnosticReport()
            let report = diagnostic.report
            let codex = report.codexLimit
            output("App-server: ok")
            output("Plan: \(CodexUsagePlanDisplay.displayLabel(rawPlanType: codex?.planType ?? report.planType))")
            output("5h window: \(codex?.fiveHour == nil ? "missing" : "ok")")
            output("Weekly window: \(codex?.weekly == nil ? "missing" : "ok")")
            CodexUsageDoctorFormatter()
                .bucketInventoryLines(from: diagnostic.fieldInventory)
                .forEach(output)
            return .success
        } catch {
            errorOutput(CodexUsageFailureGuide().message(for: error, context: .doctor))
            return .failure
        }
    }

    private func makeService(timeout: TimeInterval? = nil) throws -> CodexUsageService {
        let client = try CodexAppServerClient(timeout: timeout ?? 15)
        return CodexUsageService(client: client)
    }

    private func makeCacheStores(path: String?, mirrorCache: Bool) -> [CodexUsageCacheStore] {
        if let path {
            return [CodexUsageCacheStore(fileURL: URL(fileURLWithPath: path))]
        }
        let urls = mirrorCache ? CodexUsageCacheStore.defaultMirroredFileURLs() : [CodexUsageCacheStore.defaultFileURL()]
        return urls.map {
            CodexUsageCacheStore(fileURL: $0)
        }
    }

    static let help = """
    Usage:
      codex-usage status [--json] [--write-cache] [--mirror-cache] [--cache-path PATH] [--timeout SECONDS] [--watch SECONDS]
      codex-usage doctor

    Commands:
      status   Print current Codex 5-hour and weekly usage.
      doctor   Check Codex CLI and app-server usage access.
    """
}

let cli = CLI(
    arguments: CommandLine.arguments,
    output: { print($0) },
    errorOutput: { fputs($0 + "\n", stderr) }
)

exit(cli.run().rawValue)
