import SwiftUI
import Combine

@MainActor
final class DNSLookupSession: DiagnosticSession {

    @Published private(set) var output = ""
    @Published private(set) var isRunning = false

    let host: String
    var subtitle: String { host }

    private let runner = DNSLookupRunner()

    init(host: String) {
        self.host = host
    }

    func start() {
        guard !isRunning else { return }
        output = "dig \(host) A AAAA\n\n"
        isRunning = true

        runner.run(host: host) { [weak self] chunk in
            self?.output += chunk
        } onComplete: { [weak self] status in
            guard let self else { return }
            self.isRunning = false
            if status != 0, status != 15 {
                self.output += "\n(dig exited with status \(status))"
            }
        }
    }

    func cancel() {
        runner.cancel()
        isRunning = false
    }
}

@MainActor
final class PingSession: DiagnosticSession {

    @Published private(set) var output = ""
    @Published private(set) var isRunning = false

    let gateway: String?
    var subtitle: String { gateway ?? menuUnavailable }

    private let runner = PingRunner()

    init(gateway: String?) {
        self.gateway = gateway
    }

    func start() {
        guard !isRunning else { return }
        guard let gateway else {
            output = "Gateway unavailable\n"
            return
        }

        output = "ping \(gateway)\n\n"
        isRunning = true

        runner.run(gateway: gateway) { [weak self] chunk in
            self?.output += chunk
        } onComplete: { [weak self] status in
            guard let self else { return }
            self.isRunning = false
            if status != 0, status != 15 {
                self.output += "\n(ping exited with status \(status))"
            }
        }
    }

    func cancel() {
        runner.cancel()
        isRunning = false
    }
}

@MainActor
final class TCPConnectSession: DiagnosticSession {

    @Published private(set) var output = ""
    @Published private(set) var isRunning = false

    let host: String
    let port: Int
    var subtitle: String { "\(host):\(port)" }

    private let runner = TCPConnectRunner()

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    func start() {
        guard !isRunning else { return }
        output = "Connecting to \(host):\(port)...\n\n"
        isRunning = true

        runner.run(host: host, port: port) { [weak self] chunk in
            self?.output += chunk
        } onComplete: { [weak self] in
            self?.isRunning = false
        }
    }

    func cancel() {
        runner.cancel()
        isRunning = false
    }
}

struct DNSLookupView: View {
    @ObservedObject var session: DNSLookupSession
    var body: some View { DiagnosticOutputView(title: "DNS Lookup", session: session) }
}

struct PingView: View {
    @ObservedObject var session: PingSession
    var body: some View { DiagnosticOutputView(title: "Ping", session: session) }
}

struct TCPConnectView: View {
    @ObservedObject var session: TCPConnectSession
    var body: some View { DiagnosticOutputView(title: "TCP Port Check", session: session) }
}
