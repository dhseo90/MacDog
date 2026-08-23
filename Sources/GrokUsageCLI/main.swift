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
        case "-h", "--help", "help":
            output(Self.help)
            return .success
        default:
            errorOutput("Unknown command: \(command)\n\n\(Self.help)")
            return .usage
        }
    }

    private func runStatus(_ args: [String]) -> ExitCode {
        var writeCache = false
        var timeout: TimeInterval = 15
        var cacheDirectory: URL?
        var index = 0
        while index < args.count {
            switch args[index] {
            case "--write-cache":
                writeCache = true
            case "--timeout":
                guard index + 1 < args.count,
                      let value = TimeInterval(args[index + 1]),
                      value > 0 else {
                    errorOutput("--timeout requires a positive number of seconds.")
                    return .usage
                }
                timeout = value
                index += 1
            case "--cache-directory":
                guard index + 1 < args.count else {
                    errorOutput("--cache-directory requires a directory path.")
                    return .usage
                }
                cacheDirectory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
                index += 1
            default:
                errorOutput("Unknown status option: \(args[index])")
                return .usage
            }
            index += 1
        }

        guard writeCache else {
            errorOutput("status requires --write-cache.")
            return .usage
        }

        let store: GrokUsageCacheStore
        if let cacheDirectory {
            guard let allowed = Self.allowedCacheStore(directory: cacheDirectory) else {
                errorOutput("cache directory is not allowed.")
                return .usage
            }
            store = allowed
        } else {
            store = GrokUsageCacheStore()
        }

        do {
            let service = GrokUsageFetchService(
                store: store,
                transport: URLSessionGrokBillingTransport(),
                timeout: timeout
            )
            let result = try service.writeCache()
            output(Self.statusLine(for: result, store: store))
            if case .failed = result {
                return .failure
            }
            return .success
        } catch {
            errorOutput("Grok usage cache write failed.")
            return .failure
        }
    }

    private static func statusLine(for result: GrokUsageIngestResult, store: GrokUsageCacheStore) -> String {
        switch result {
        case .stored(let weekly):
            return "Grok · 주간 \(Int(weekly.usedPercent.rounded()))%"
        case .failed(let code):
            if let weekly = try? store.read().weekly {
                return "Grok · \(code) · 주간 \(Int(weekly.usedPercent.rounded()))%"
            }
            return "Grok · \(code)"
        }
    }

    private static func allowedCacheStore(directory: URL) -> GrokUsageCacheStore? {
        let requestedDirectory = directory.standardizedFileURL.resolvingSymlinksInPath()
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
        return GrokUsageCacheStore(
            fileURL: requestedDirectory.appendingPathComponent("grok-usage.json"),
            historyFileURL: requestedDirectory.appendingPathComponent("grok-usage-history.json")
        )
    }

    static let help = """
    usage: macdog-grok-usage status --write-cache [--timeout SECONDS]

    Writes the unofficial SuperGrok weekly pool into grok-usage.json.
    --timeout is the billing HTTP timeout in seconds (default 15).
    Does not print tokens or raw billing responses.
    """
}

exit(Int32(CLI(
    arguments: CommandLine.arguments,
    output: { FileHandle.standardOutput.write(Data(($0 + "\n").utf8)) },
    errorOutput: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
).run().rawValue))
