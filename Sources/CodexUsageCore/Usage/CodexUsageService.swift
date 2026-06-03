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
        return try reportBuilder.build(from: response)
    }

    public func readDiagnosticReport() throws -> CodexUsageDiagnosticReport {
        let diagnostic = try client.readRateLimitDiagnostic()
        return try reportBuilder.buildDiagnosticReport(
            from: diagnostic.response,
            fieldInventory: diagnostic.fieldInventory
        )
    }
}
