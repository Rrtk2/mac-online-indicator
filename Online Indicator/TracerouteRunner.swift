import Foundation

/// Runs `/usr/sbin/traceroute` off the main thread and streams stdout/stderr.
final class TracerouteRunner {

    private let runner = DiagnosticProcessRunner(label: "com.onlineindicator.traceroute")

    func run(
        host: String,
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor (Int32) -> Void
    ) {
        runner.run(
            executable: "/usr/sbin/traceroute",
            arguments: ["-m", "30", host],
            onOutput: onOutput,
            onComplete: onComplete
        )
    }

    func cancel() {
        runner.cancel()
    }
}
