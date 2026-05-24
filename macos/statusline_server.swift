import Foundation
import Network

final class StatusLineServer {
    private var listener: NWListener?
    private var latestData: Data?
    private let queue = DispatchQueue(label: "com.claudemonitor.server", qos: .utility)
    private let lock = NSLock()
    private var _running = false

    var isRunning: Bool { _running }
    var onPost: ((Data) -> Void)?

    func start() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: 22666),
              let listener = try? NWListener(using: params, on: port) else { return }

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:              self?._running = true
            case .failed, .cancelled: self?._running = false
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        listener.start(queue: queue)
        self.listener = listener
        _running = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        _running = false
    }

    // MARK: - Connection handling

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 131_072) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else {
                conn.cancel(); return
            }
            self.route(text, conn: conn)
        }
    }

    private func route(_ text: String, conn: NWConnection) {
        let firstLine = text.prefix(while: { !$0.isNewline })
        let parts = firstLine.split(separator: " ", maxSplits: 2)
        let method = parts.count > 0 ? String(parts[0]) : ""
        let path   = parts.count > 1 ? String(parts[1]) : ""

        switch (method, path) {
        case ("GET", "/statusline"):
            lock.lock()
            let body = latestData ?? Data("null".utf8)
            lock.unlock()
            reply(conn, status: 200, body: body, contentType: "application/json")

        case ("POST", "/statusline"):
            guard let range = text.range(of: "\r\n\r\n") else {
                reply(conn, status: 400, body: Data()); return
            }
            let body = Data(text[range.upperBound...].utf8)
            lock.lock()
            latestData = body.isEmpty ? nil : body
            let cb = onPost
            lock.unlock()
            if !body.isEmpty { cb?(body) }
            reply(conn, status: 200, body: Data())

        default:
            reply(conn, status: 404, body: Data("Not Found".utf8))
        }
    }

    private func reply(_ conn: NWConnection, status: Int, body: Data, contentType: String = "text/plain") {
        let phrase: String
        switch status {
        case 200: phrase = "OK"
        case 400: phrase = "Bad Request"
        case 404: phrase = "Not Found"
        default:  phrase = "Error"
        }
        let header = "HTTP/1.1 \(status) \(phrase)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
    }
}
