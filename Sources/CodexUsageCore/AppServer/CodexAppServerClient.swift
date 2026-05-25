import Foundation

public final class CodexAppServerClient {
    private let codexURL: URL
    private let timeout: TimeInterval
    private let decoder = JSONDecoder()

    public init(codexURL: URL, timeout: TimeInterval = 15) {
        self.codexURL = codexURL
        self.timeout = timeout
    }

    public convenience init(resolver: CodexCLIResolver = CodexCLIResolver(), timeout: TimeInterval = 15) throws {
        try self.init(codexURL: resolver.resolve(), timeout: timeout)
    }

    public func readRateLimits() throws -> RateLimitsResponse {
        let process = Process()
        process.executableURL = codexURL
        process.arguments = ["app-server"]

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
        let initializeData = try reader.waitForResponse(id: 1, timeout: timeout)
        _ = try decodeResponse(InitializeResponse.self, from: initializeData, id: 1)

        try sendRateLimitRead(to: stdin.fileHandleForWriting)
        let rateLimitData = try reader.waitForResponse(id: 2, timeout: timeout)
        return try decodeResponse(RateLimitsResponse.self, from: rateLimitData, id: 2)
    }

    private func sendInitialize(to handle: FileHandle) throws {
        try send(
            id: 1,
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codex-usage",
                    "title": "Codex Usage",
                    "version": "0.1.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "requestAttestation": false
                ]
            ],
            to: handle
        )
    }

    private func sendRateLimitRead(to handle: FileHandle) throws {
        try send(id: 2, method: "account/rateLimits/read", params: nil, to: handle)
    }

    private func send(id: Int, method: String, params: Any?, to handle: FileHandle) throws {
        var payload: [String: Any] = [
            "id": id,
            "method": method
        ]
        if let params {
            payload["params"] = params
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        var line = Data(data)
        line.append(0x0A)
        handle.write(line)
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

