import Foundation

/// Runs `/sbin/ping` off the main thread and streams stdout/stderr.
final class PingRunner {

    private let runner = DiagnosticProcessRunner(label: "com.onlineindicator.ping")

    func run(
        gateway: String,
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor (Int32) -> Void
    ) {
        runner.run(
            executable: "/sbin/ping",
            arguments: ["-c", "10", "-W", "2000", gateway],
            onOutput: onOutput,
            onComplete: onComplete
        )
    }

    func cancel() {
        runner.cancel()
    }
}
