//
//  FaviconService.swift
//  MCPContxt
//
//  Fetches and caches favicons from MCP server domains
//

import Foundation
import AppKit
import Combine

class FaviconService: ObservableObject {
    static let shared = FaviconService()

    @Published private(set) var icons: [String: NSImage] = [:]

    private let cache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private var inFlightRequests: Set<String> = []

    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MCPContxt/IconCache")
    }

    private init() {
        // Ensure cache directory exists
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Get icon for a server, triggering async fetch if needed
    func icon(for serverURL: String, serverId: String) -> NSImage? {
        // Check memory cache first
        if let cached = icons[serverId] {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDisk(serverId: serverId) {
            icons[serverId] = diskCached
            return diskCached
        }

        // Trigger async fetch if not already in flight
        if !inFlightRequests.contains(serverId) {
            fetchFavicon(for: serverURL, serverId: serverId)
        }

        return nil
    }

    private func fetchFavicon(for serverURL: String, serverId: String) {
        inFlightRequests.insert(serverId)

        Task {
            defer { inFlightRequests.remove(serverId) }

            guard let baseDomain = extractBaseDomain(from: serverURL) else { return }

            // Try common favicon locations in order of preference
            let faviconURLs = [
                "https://\(baseDomain)/apple-touch-icon.png",
                "https://\(baseDomain)/favicon.png",
                "https://\(baseDomain)/favicon.ico",
                "https://www.google.com/s2/favicons?domain=\(baseDomain)&sz=64"
            ]

            for urlString in faviconURLs {
                if let image = await downloadImage(from: urlString) {
                    // Resize to standard size for consistency
                    let resized = resizeImage(image, to: NSSize(width: 64, height: 64))
                    icons[serverId] = resized
                    saveToDisk(image: resized, serverId: serverId)
                    return
                }
            }
        }
    }

    /// Extract the main service domain from an MCP URL
    /// e.g., "https://mcp.slack.com/mcp" → "slack.com"
    private func extractBaseDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }

        let components = host.components(separatedBy: ".")

        // Handle special cases
        // mcp.slack.com → slack.com
        // api.github.com → github.com
        // bindings.mcp.cloudflare.com → cloudflare.com
        if components.count >= 2 {
            // Take last two parts (domain.tld)
            return components.suffix(2).joined(separator: ".")
        }

        return host
    }

    private func downloadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data),
                  image.isValid else {
                return nil
            }

            return image
        } catch {
            return nil
        }
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    // MARK: - Disk Caching

    private func loadFromDisk(serverId: String) -> NSImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(serverId).png")
        guard let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveToDisk(image: NSImage, serverId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(serverId).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: fileURL)
    }

    /// Clear all cached icons (memory and disk)
    func clearCache() {
        icons.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
