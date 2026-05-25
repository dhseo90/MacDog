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
        var index = 0

        while index < args.count {
            switch args[index] {
            case "--json":
                json = true
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
            let exitCode = printStatus(json: json)
            if exitCode != .success || watchInterval == nil {
                return exitCode
            }
            sleep(watchInterval!)
        } while true
    }

    private func printStatus(json: Bool) -> ExitCode {
        do {
            let formatter = CodexUsageFormatter()
            let report = try makeService().readReport()

            if json {
                let data = try formatter.json(from: report)
                output(String(decoding: data, as: UTF8.self))
            } else {
                output(formatter.text(from: report))
            }
            return .success
        } catch {
            errorOutput("codex-usage status failed: \(error.localizedDescription)")
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
            let report = try service.readReport()
            let codex = report.codexLimit
            output("App-server: ok")
            output("Plan: \(codex?.planType ?? report.planType ?? "unknown")")
            output("5h window: \(codex?.fiveHour == nil ? "missing" : "ok")")
            output("Weekly window: \(codex?.weekly == nil ? "missing" : "ok")")
            return .success
        } catch {
            errorOutput("Doctor failed: \(error.localizedDescription)")
            return .failure
        }
    }

    private func makeService() throws -> CodexUsageService {
        let client = try CodexAppServerClient()
        return CodexUsageService(client: client)
    }

    static let help = """
    Usage:
      codex-usage status [--json] [--watch SECONDS]
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

