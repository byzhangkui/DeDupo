import AppKit

/// Monitors disk mount/unmount events and reports available volumes.
final class VolumeMonitor {
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?
    private let onChange: ([VolumeInfo]) -> Void

    init(onChange: @escaping ([VolumeInfo]) -> Void) {
        self.onChange = onChange
    }

    /// Start monitoring volume mount/unmount events.
    func startMonitoring() {
        // Report initial volumes
        onChange(Self.currentVolumes())

        let center = NSWorkspace.shared.notificationCenter

        mountObserver = center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onChange(Self.currentVolumes())
        }

        unmountObserver = center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onChange(Self.currentVolumes())
        }
    }

    /// Stop monitoring.
    func stopMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        if let obs = mountObserver { center.removeObserver(obs) }
        if let obs = unmountObserver { center.removeObserver(obs) }
    }

    /// Get currently mounted volumes.
    static func currentVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return volumes.compactMap { url in
            guard let resources = try? url.resourceValues(forKeys: Set(keys)),
                  let name = resources.volumeName else { return nil }

            let isExternal = !(resources.volumeIsInternal ?? true)

            return VolumeInfo(
                id: url.path,
                name: name,
                path: url.path,
                isExternal: isExternal
            )
        }
    }
}
