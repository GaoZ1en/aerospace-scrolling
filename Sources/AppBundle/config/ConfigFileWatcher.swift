import Common
import Foundation

private struct ConfigFileWatcher: ~Copyable {
    private let source: DispatchSourceFileSystemObject
    private let fd: Int32

    init?(url: URL, onChange: @escaping @MainActor () -> Void) {
        fd = unsafe open(url.path, O_EVTONLY)
        if fd < 0 { return nil }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke],
            queue: .main,
        )
        source.setEventHandler { MainActor.checkIsolated { onChange() } }
        source.setCancelHandler { [fd] in close(fd) }
        source.activate()
    }

    deinit {
        source.cancel()
    }
}

@MainActor private var currentWatcher: ConfigFileWatcher? = nil
@MainActor private var debounceTask: Task<Void, any Error>? = nil

private let debounceDelay: Duration = .milliseconds(200)

@MainActor func syncConfigFileWatcher() {
    // Auto-reload config not supported in this fork
}
