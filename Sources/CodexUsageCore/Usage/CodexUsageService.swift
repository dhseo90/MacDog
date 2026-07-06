import Foundation

public struct CodexUsageService {
    private let readRateLimitsAction: () throws -> RateLimitsResponse
    private let readRateLimitDiagnosticAction: () throws -> CodexAppServerRateLimitDiagnostic
    private let refreshAuthTokensAction: () throws -> ChatGPTAuthTokensRefreshResponse
    private let readLocalAuthTokensAction: () throws -> ChatGPTAuthTokensRefreshResponse
    private let resetCreditDetailsFetcher: CodexResetCreditDetailsFetching?
    private let reportBuilder: CodexUsageReportBuilder
    private let resetCreditDetailsTimeout: TimeInterval

    public init(
        client: CodexAppServerClient,
        resetCreditDetailsFetcher: CodexResetCreditDetailsFetching? = CodexResetCreditDetailsClient(),
        resetCreditDetailsTimeout: TimeInterval = 15,
        reportBuilder: CodexUsageReportBuilder = CodexUsageReportBuilder()
    ) {
        self.init(
            readRateLimits: { try client.readRateLimits() },
            readRateLimitDiagnostic: { try client.readRateLimitDiagnostic() },
            refreshAuthTokens: { try client.refreshChatGPTAuthTokens() },
            readLocalAuthTokens: { try CodexLocalAuthTokenProvider().readTokens() },
            resetCreditDetailsFetcher: resetCreditDetailsFetcher,
            resetCreditDetailsTimeout: resetCreditDetailsTimeout,
            reportBuilder: reportBuilder
        )
    }

    init(
        readRateLimits: @escaping () throws -> RateLimitsResponse,
        readRateLimitDiagnostic: @escaping () throws -> CodexAppServerRateLimitDiagnostic,
        refreshAuthTokens: @escaping () throws -> ChatGPTAuthTokensRefreshResponse,
        readLocalAuthTokens: @escaping () throws -> ChatGPTAuthTokensRefreshResponse = {
            try CodexLocalAuthTokenProvider().readTokens()
        },
        resetCreditDetailsFetcher: CodexResetCreditDetailsFetching?,
        resetCreditDetailsTimeout: TimeInterval = 15,
        reportBuilder: CodexUsageReportBuilder = CodexUsageReportBuilder()
    ) {
        self.readRateLimitsAction = readRateLimits
        self.readRateLimitDiagnosticAction = readRateLimitDiagnostic
        self.refreshAuthTokensAction = refreshAuthTokens
        self.readLocalAuthTokensAction = readLocalAuthTokens
        self.resetCreditDetailsFetcher = resetCreditDetailsFetcher
        self.reportBuilder = reportBuilder
        self.resetCreditDetailsTimeout = resetCreditDetailsTimeout
    }

    public func readReport() throws -> CodexUsageReport {
        let response = try readRateLimitsAction()
        let report = try reportBuilder.build(from: response)
        return try enrichResetCreditsIfNeeded(report)
    }

    public func readDiagnosticReport() throws -> CodexUsageDiagnosticReport {
        let diagnostic = try readRateLimitDiagnosticAction()
        let report = try reportBuilder.buildDiagnosticReport(
            from: diagnostic.response,
            fieldInventory: diagnostic.fieldInventory
        )
        return CodexUsageDiagnosticReport(
            report: try enrichResetCreditsIfNeeded(report.report),
            fieldInventory: report.fieldInventory
        )
    }

    private func enrichResetCreditsIfNeeded(_ report: CodexUsageReport) throws -> CodexUsageReport {
        guard let resetCredits = report.resetCredits,
              resetCredits.availableCount > 0,
              resetCredits.credits.count < resetCredits.availableCount,
              let resetCreditDetailsFetcher
        else {
            return report
        }

        let tokens: ChatGPTAuthTokensRefreshResponse
        do {
            tokens = try refreshAuthTokensAction()
        } catch {
            guard Self.canFallbackToLocalAuth(after: error) else {
                throw error
            }
            tokens = try readLocalAuthTokensAction()
        }
        let detailed = try resetCreditDetailsFetcher.fetch(
            accessToken: tokens.accessToken,
            accountId: tokens.chatgptAccountId,
            timeout: resetCreditDetailsTimeout
        )
        return report.replacingResetCredits(detailed)
    }

    private static func canFallbackToLocalAuth(after error: Error) -> Bool {
        guard let appServerError = error as? CodexAppServerError else {
            return false
        }
        switch appServerError {
        case .rpcError(id: CodexAppServerRequestFactory.chatGPTAuthTokensRefreshRequestID, let message):
            return message.contains("unknown variant") &&
                message.contains("account/chatgptAuthTokens/refresh")
        default:
            return false
        }
    }
}
