import Foundation

public protocol PrivilegedHelperRequestSending {
    func send(
        _ request: PrivilegedHelperRequest,
        completion: @escaping (Result<PrivilegedHelperResponse, Error>) -> Void
    )
}

public final class MacDogPrivilegedHelperClient: PrivilegedHelperRequestSending {
    private let connection: NSXPCConnection

    public convenience init(machServiceName: String = MacDogPrivilegedHelperContract.machServiceName) {
        self.init(connection: NSXPCConnection(machServiceName: machServiceName, options: .privileged))
    }

    init(connection: NSXPCConnection) {
        self.connection = connection
        connection.remoteObjectInterface = NSXPCInterface(with: MacDogPrivilegedHelperXPCProtocol.self)
        connection.resume()
    }

    deinit {
        connection.invalidate()
    }

    public func send(
        _ request: PrivilegedHelperRequest,
        completion: @escaping (Result<PrivilegedHelperResponse, Error>) -> Void
    ) {
        let payload: Data
        do {
            payload = try PrivilegedHelperJSONCodec.encode(request)
        } catch {
            completion(.failure(error))
            return
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            completion(.failure(error))
        }) as? MacDogPrivilegedHelperXPCProtocol else {
            completion(.failure(PrivilegedHelperClientError.proxyUnavailable))
            return
        }

        proxy.handleRequest(payload as NSData) { responseData in
            do {
                completion(.success(try PrivilegedHelperJSONCodec.decodeResponse(responseData as Data)))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

public enum PrivilegedHelperClientError: LocalizedError, Equatable, Sendable {
    case proxyUnavailable

    public var errorDescription: String? {
        switch self {
        case .proxyUnavailable:
            "권한 도우미 연결을 만들 수 없습니다."
        }
    }
}
