import Foundation

final class JSONRPCLineReader: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var responses: [Int: Data] = [:]
    private var waiters: [Int: DispatchSemaphore] = [:]

    func start(reading handle: FileHandle) {
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }
    }

    func waitForResponse(id: Int, timeout: TimeInterval) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)

        lock.lock()
        if let response = responses[id] {
            responses[id] = nil
            lock.unlock()
            return response
        }
        waiters[id] = semaphore
        lock.unlock()

        let deadline = DispatchTime.now() + timeout
        guard semaphore.wait(timeout: deadline) == .success else {
            lock.lock()
            waiters[id] = nil
            lock.unlock()
            throw CodexAppServerError.responseTimedOut(id: id)
        }

        lock.lock()
        let response = responses[id]
        responses[id] = nil
        waiters[id] = nil
        lock.unlock()

        guard let response else {
            throw CodexAppServerError.responseTimedOut(id: id)
        }
        return response
    }

    private func consume(_ data: Data) {
        lock.lock()
        buffer.append(data)

        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            handleLine(Data(line))
        }

        lock.unlock()
    }

    private func handleLine(_ lineData: Data) {
        guard !lineData.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: lineData),
              let dictionary = object as? [String: Any],
              let id = dictionary["id"] as? Int
        else {
            return
        }

        responses[id] = lineData
        waiters[id]?.signal()
    }
}
