import Foundation

public struct CodexAppServerRateLimitDiagnostic: Equatable, Sendable {
    public let response: RateLimitsResponse
    public let fieldInventory: CodexUsageFieldInventory

    public init(response: RateLimitsResponse, fieldInventory: CodexUsageFieldInventory) {
        self.response = response
        self.fieldInventory = fieldInventory
    }
}

public final class CodexAppServerClient {
    public static let defaultWorkingDirectoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
    public static let legacyArguments = ["app-server"]
    public static let proxyArguments = ["app-server", "proxy"]

    private let codexURL: URL
    private let timeout: TimeInterval
    private let workingDirectoryURL: URL
    private let requestFactory = CodexAppServerRequestFactory()
    private let decoder = JSONDecoder()

    public init(
        codexURL: URL,
        timeout: TimeInterval = 15,
        workingDirectoryURL: URL = CodexAppServerClient.defaultWorkingDirectoryURL
    ) {
        self.codexURL = codexURL
        self.timeout = timeout
        self.workingDirectoryURL = workingDirectoryURL
    }

    public convenience init(resolver: CodexCLIResolver = CodexCLIResolver(), timeout: TimeInterval = 15) throws {
        try self.init(codexURL: resolver.resolve(), timeout: timeout)
    }

    public func readRateLimits() throws -> RateLimitsResponse {
        var lastError: Error?
        for arguments in appServerArgumentCandidates() {
            do {
                return try readRateLimits(arguments: arguments)
            } catch {
                lastError = error
                guard Self.canRetryWithNextInvocation(after: error) else {
                    throw error
                }
            }
        }

        throw lastError ?? CodexAppServerError.processLaunchFailed("No Codex app-server invocation was available.")
    }

    public func readRateLimitDiagnostic() throws -> CodexAppServerRateLimitDiagnostic {
        var lastError: Error?
        for arguments in appServerArgumentCandidates() {
            do {
                let responseData = try readRateLimitResponseData(arguments: arguments)
                let response = try decodeResponse(
                    RateLimitsResponse.self,
                    from: responseData,
                    id: CodexAppServerRequestFactory.rateLimitReadRequestID
                )
                let fieldInventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: responseData)
                return CodexAppServerRateLimitDiagnostic(
                    response: response,
                    fieldInventory: fieldInventory
                )
            } catch {
                lastError = error
                guard Self.canRetryWithNextInvocation(after: error) else {
                    throw error
                }
            }
        }

        throw lastError ?? CodexAppServerError.processLaunchFailed("No Codex app-server invocation was available.")
    }

    static func argumentCandidates(proxySubcommandAvailable: Bool, daemonAvailable: Bool) -> [[String]] {
        (proxySubcommandAvailable && daemonAvailable) ? [proxyArguments, legacyArguments] : [legacyArguments]
    }

    static func canRetryWithNextInvocation(after error: Error) -> Bool {
        guard let appServerError = error as? CodexAppServerError else {
            return false
        }
        switch appServerError {
        case .processLaunchFailed, .stdinClosed, .invalidJSONLine, .responseTimedOut(id: CodexAppServerRequestFactory.initializeRequestID):
            return true
        case .codexBinaryNotFound,
             .codexBinaryNotExecutable,
             .responseTimedOut,
             .responseMissingResult,
             .rpcError:
            return false
        }
    }

    private func readRateLimits(arguments: [String]) throws -> RateLimitsResponse {
        let rateLimitData = try readRateLimitResponseData(arguments: arguments)
        return try decodeResponse(
            RateLimitsResponse.self,
            from: rateLimitData,
            id: CodexAppServerRequestFactory.rateLimitReadRequestID
        )
    }

    private func readRateLimitResponseData(arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = codexURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectoryURL

        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        let reader = JSONRPCLineReader()
        reader.start(reading: stdout.fileHandleForReading)

        do {
            try process.run()
        } catch {
            throw CodexAppServerError.processLaunchFailed(error.localizedDescription)
        }

        defer {
            stdout.fileHandleForReading.readabilityHandler = nil
            stdin.fileHandleForWriting.closeFile()
            if process.isRunning {
                process.terminate()
            }
        }

        try sendInitialize(to: stdin.fileHandleForWriting)
        let initializeData = try reader.waitForResponse(
            id: CodexAppServerRequestFactory.initializeRequestID,
            timeout: timeout
        )
        _ = try decodeResponse(
            InitializeResponse.self,
            from: initializeData,
            id: CodexAppServerRequestFactory.initializeRequestID
        )

        try sendRateLimitRead(to: stdin.fileHandleForWriting)
        let rateLimitData = try reader.waitForResponse(
            id: CodexAppServerRequestFactory.rateLimitReadRequestID,
            timeout: timeout
        )
        return rateLimitData
    }

    private func appServerArgumentCandidates() -> [[String]] {
        let proxySubcommandAvailable = isProxySubcommandAvailable()
        let daemonAvailable = proxySubcommandAvailable && isDaemonAvailable()
        return Self.argumentCandidates(
            proxySubcommandAvailable: proxySubcommandAvailable,
            daemonAvailable: daemonAvailable
        )
    }

    private func isProxySubcommandAvailable() -> Bool {
        runCodexProbe(arguments: ["app-server", "proxy", "--help"])
    }

    private func isDaemonAvailable() -> Bool {
        runCodexProbe(arguments: ["app-server", "daemon", "version"])
    }

    private func runCodexProbe(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = codexURL
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectoryURL
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }

        let probeTimeout = min(max(timeout / 5, 1), 3)
        if group.wait(timeout: .now() + probeTimeout) != .success {
            process.terminate()
            return false
        }

        return process.terminationStatus == 0
    }

    private func sendInitialize(to handle: FileHandle) throws {
        handle.write(try requestFactory.initializeRequest())
    }

    private func sendRateLimitRead(to handle: FileHandle) throws {
        handle.write(try requestFactory.rateLimitReadRequest())
    }

    private func decodeResponse<Result: Decodable>(
        _ type: Result.Type,
        from data: Data,
        id: Int
    ) throws -> Result {
        let envelope = try decoder.decode(JSONRPCResponse<Result>.self, from: data)
        if let error = envelope.error {
            throw CodexAppServerError.rpcError(id: id, message: error.message)
        }
        guard let result = envelope.result else {
            throw CodexAppServerError.responseMissingResult(id: id)
        }
        return result
    }
}
