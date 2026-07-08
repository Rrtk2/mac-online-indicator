import SwiftUI
import Combine

@MainActor
final class TracerouteSession: ObservableObject {

    @Published private(set) var output = ""
    @Published private(set) var isRunning = false

    let host: String
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Traceroute")
                    .font(.headline)
                Spacer()
                if session.isRunning {
                    Button("Cancel") { session.cancel() }
                }
                Button("Copy") { copyOutput() }
                    .disabled(session.output.isEmpty)
            }

            Text(session.host)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(session.output)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { session.start() }
        .onDisappear { session.cancel() }
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.output, forType: .string)
    }
}
