import SwiftUI
import Combine

@MainActor
final class TracerouteSession: DiagnosticSession {

    @Published private(set) var output = ""
    @Published private(set) var isRunning = false

    let host: String
    var subtitle: String { host }

    private let runner = TracerouteRunner()

    init(host: String) {
        self.host = host
    }

    func start() {
        guard !isRunning else { return }
        output = "traceroute to \(host)\n\n"
        isRunning = true

        runner.run(host: host) { [weak self] chunk in
            self?.output += chunk
        } onComplete: { [weak self] status in
            guard let self else { return }
            self.isRunning = false
            if status != 0, status != 15 {
                self.output += "\n(traceroute exited with status \(status))"
            }
        }
    }

    func cancel() {
        runner.cancel()
        isRunning = false
    }
}

struct TracerouteView: View {

    @ObservedObject var session: TracerouteSession

    var body: some View {
        DiagnosticOutputView(title: "Traceroute", session: session)
    }
}
