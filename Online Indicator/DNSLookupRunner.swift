import Foundation

/// Runs `/usr/bin/dig` off the main thread and streams stdout/stderr.
final class DNSLookupRunner {

    private let runner = DiagnosticProcessRunner(label: "com.onlineindicator.dnslookup")

    func run(
        host: String,
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor (Int32) -> Void
    ) {
        runner.run(
            executable: "/usr/bin/dig",
            arguments: ["+time=2", "+tries=1", host, "A", "AAAA"],
            onOutput: onOutput,
            onComplete: onComplete
        )
    }

    func cancel() {
        runner.cancel()
    }
}
