import Foundation

/// Runs `/usr/sbin/traceroute` off the main thread and streams stdout/stderr.
final class TracerouteRunner {

    private let queue = DispatchQueue(label: "com.onlineindicator.traceroute", qos: .utility)
    private var process: Process?

    func run(
        host: String,
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor (Int32) -> Void
    ) {
        cancel()
        queue.async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
            process.arguments = ["-m", "30", host]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in onOutput(chunk) }
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                let status = proc.terminationStatus
                Task { @MainActor in onComplete(status) }
            }

            self?.process = process

            do {
                try process.run()
            } catch {
                Task { @MainActor in
                    onOutput("Failed to start traceroute: \(error.localizedDescription)\n")
                    onComplete(-1)
                }
            }
        }
    }

    func cancel() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }
}
