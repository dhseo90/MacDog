import Foundation

public struct CodexUsageService {
    private let client: CodexAppServerClient
    private let reportBuilder: CodexUsageReportBuilder

    public init(
        client: CodexAppServerClient,
        reportBuilder: CodexUsageReportBuilder = CodexUsageReportBuilder()
    ) {
        self.client = client
        self.reportBuilder = reportBuilder
    }

    public func readReport() throws -> CodexUsageReport {
        let response = try client.readRateLimits()
        return reportBuilder.build(from: response)
    }
}

