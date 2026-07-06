import Foundation

public struct ChatGPTAuthTokensRefreshResponse: Decodable, Equatable, Sendable {
    public let accessToken: String
    public let chatgptAccountId: String
    public let chatgptPlanType: String?

    public init(accessToken: String, chatgptAccountId: String, chatgptPlanType: String?) {
        self.accessToken = accessToken
        self.chatgptAccountId = chatgptAccountId
        self.chatgptPlanType = chatgptPlanType
    }
}
