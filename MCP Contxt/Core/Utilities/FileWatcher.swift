//
//  FileWatcher.swift
//  MCP Contxt
//
//  Watch for external changes to configuration files
//

import Foundation
import Combine
import SwiftUI

class FileWatcher {
    private var sources: [URL: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [URL: Int32] = [:]
    private let queue = DispatchQueue(label: "com.mcpcontxt.filewatcher", qos: .utility)

    deinit {
        stopAll()
    }

    func watch(path: URL, onChange: @escaping () -> Void) {
        // Stop existing watcher for this path if any
        stopWatching(path: path)

        let fd = open(path.path, O_EVTONLY)
        guard fd >= 0 else {
            // File doesn't exist yet, try watching parent directory
            watchParentDirectory(for: path, onChange: onChange)
            return
        }

        fileDescriptors[path] = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                onChange()
            }

            // Check if file was deleted/renamed
            if source.data.contains(.delete) || source.data.contains(.rename) {
                self?.stopWatching(path: path)
                // Try to re-establish watch after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.watch(path: path, onChange: onChange)
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        sources[path] = source
        source.resume()
    }

    func stopWatching(path: URL) {
        if let source = sources[path] {
            source.cancel()
            sources.removeValue(forKey: path)
        }
        fileDescriptors.removeValue(forKey: path)
    }

    func stopAll() {
        for (_, source) in sources {
            source.cancel()
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    private func watchParentDirectory(for path: URL, onChange: @escaping () -> Void) {
        let parent = path.deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: parent.path) else {
            return
        }

        let fd = open(parent.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileDescriptors[path] = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            // Check if our target file now exists
            if FileManager.default.fileExists(atPath: path.path) {
                self?.stopWatching(path: path)
                self?.watch(path: path, onChange: onChange)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        sources[path] = source
        source.resume()
    }

    var watchedPaths: [URL] {
        Array(sources.keys)
    }
}

// MARK: - Configuration File Watcher

@MainActor
class ConfigurationFileWatcher: ObservableObject {
    static let shared = ConfigurationFileWatcher()

    @Published private(set) var hasExternalChanges: Bool = false
    @Published private(set) var changedTargets: Set<SyncTarget> = []

    private let fileWatcher = FileWatcher()
    private var onChange: (() -> Void)?

    private init() {}

    func startWatching(onChange: @escaping () -> Void) {
        self.onChange = onChange

        // Watch Claude Desktop config
        fileWatcher.watch(path: SyncTarget.claudeDesktop.configPath) { [weak self] in
            Task { @MainActor in
                self?.hasExternalChanges = true
                self?.changedTargets.insert(.claudeDesktop)
                self?.onChange?()
            }
        }

        // Watch Claude Code config
        fileWatcher.watch(path: SyncTarget.claudeCodeUser.configPath) { [weak self] in
            Task { @MainActor in
                self?.hasExternalChanges = true
                self?.changedTargets.insert(.claudeCodeUser)
                self?.onChange?()
            }
        }
    }

    func stopWatching() {
        fileWatcher.stopAll()
    }

    func clearChanges() {
        hasExternalChanges = false
        changedTargets.removeAll()
    }
}
