import Foundation

/// Runs a subprocess off the main thread and streams combined stdout/stderr.
final class DiagnosticProcessRunner {

    private let queue: DispatchQueue
    private var process: Process?

    init(label: String) {
        queue = DispatchQueue(label: label, qos: .utility)
    }

    func run(
        executable: String,
        arguments: [String],
        onOutput: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor (Int32) -> Void
    ) {
        cancel()
        queue.async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

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
                    onOutput("Failed to start \(URL(fileURLWithPath: executable).lastPathComponent): \(error.localizedDescription)\n")
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
