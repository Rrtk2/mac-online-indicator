import SwiftUI
import Combine

@MainActor
protocol DiagnosticSession: AnyObject, ObservableObject {
    var output: String { get }
    var isRunning: Bool { get }
    var subtitle: String { get }
    func start()
    func cancel()
}

struct DiagnosticOutputView<Session: DiagnosticSession>: View {

    let title: String
    @ObservedObject var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if session.isRunning {
                    Button("Cancel") { session.cancel() }
                }
                Button("Copy") { copyOutput() }
                    .disabled(session.output.isEmpty)
            }

            Text(session.subtitle)
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
