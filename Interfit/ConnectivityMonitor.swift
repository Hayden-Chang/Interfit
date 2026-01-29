import Foundation
import Network

@MainActor
final class ConnectivityMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "interfit.connectivity.monitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor

#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-forceOffline") {
            isOnline = false
            return
        }
        if args.contains("-forceOnline") {
            isOnline = true
            return
        }
#endif

        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
