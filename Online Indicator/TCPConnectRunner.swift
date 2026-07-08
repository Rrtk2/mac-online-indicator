import Foundation
import Network

/// Tests TCP connectivity using `NWConnection`.
final class TCPConnectRunner {

    private let queue = DispatchQueue(label: "com.onlineindicator.tcpconnect", qos: .utility)
    private var connection: NWConnection?
    private var didFinish = false

    func run(
        host: String,
        port: Int,
        timeout: TimeInterval = 5,
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void
    ) {
        cancel()
        didFinish = false

        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
            Task { @MainActor in
                onOutput("Invalid port: \(port)\n")
                onComplete()
            }
            return
        }

        let start = Date()
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .tcp
        )
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self, !self.didFinish else { return }

            switch state {
            case .ready:
                self.finish(
                    output: String(format: "TCP connect to %@:%d succeeded (%.1f ms)\n", host, port, Date().timeIntervalSince(start) * 1000),
                    connection: connection,
                    onOutput: onOutput,
                    onComplete: onComplete
                )
            case .failed(let error):
                self.finish(
                    output: "TCP connect to \(host):\(port) failed: \(error.localizedDescription)\n",
                    connection: connection,
                    onOutput: onOutput,
                    onComplete: onComplete
                )
            default:
                break
            }
        }

        connection.start(queue: queue)

        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self, !self.didFinish else { return }
            self.finish(
                output: "TCP connect to \(host):\(port) timed out after \(Int(timeout)) s\n",
                connection: connection,
                onOutput: onOutput,
                onComplete: onComplete
            )
        }
    }

    func cancel() {
        didFinish = true
        connection?.cancel()
        connection = nil
    }

    private func finish(
        output: String,
        connection: NWConnection,
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void
    ) {
        guard !didFinish else { return }
        didFinish = true
        connection.cancel()
        self.connection = nil
        Task { @MainActor in
            onOutput(output)
            onComplete()
        }
    }
}
