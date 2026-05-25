import Foundation

struct JSONRPCResponse<Result: Decodable>: Decodable {
    let id: Int
    let result: Result?
    let error: JSONRPCError?
}

struct JSONRPCError: Decodable, Equatable {
    let code: Int?
    let message: String
}

struct InitializeResponse: Decodable, Equatable {
    let userAgent: String
    let codexHome: String
    let platformFamily: String
    let platformOs: String
}

