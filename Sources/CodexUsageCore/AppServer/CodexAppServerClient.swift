import Foundation

public final class CodexAppServerClient {
    public static let defaultWorkingDirectoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)

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
        let process = Process()
        process.executableURL = codexURL
        process.arguments = ["app-server"]
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
        return try decodeResponse(
            RateLimitsResponse.self,
            from: rateLimitData,
            id: CodexAppServerRequestFactory.rateLimitReadRequestID
        )
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
