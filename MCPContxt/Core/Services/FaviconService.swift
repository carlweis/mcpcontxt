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
    /// For stdio servers (no URL), pass nil and we'll infer from serverId
    func icon(for serverURL: String?, serverId: String) -> NSImage? {
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

    private func fetchFavicon(for serverURL: String?, serverId: String) {
        inFlightRequests.insert(serverId)

        Task {
            defer {
                Task { @MainActor in
                    inFlightRequests.remove(serverId)
                }
            }

            // Determine the domain to fetch favicon from
            let targetDomain: String?
            let targetBaseURL: String?
            
            if let url = serverURL, !url.isEmpty {
                // HTTP/SSE server - use provided URL
                targetDomain = extractBaseDomain(from: url)
                targetBaseURL = extractBaseURL(from: url)
            } else {
                // stdio server - infer from serverId
                targetDomain = inferDomainFromServerId(serverId)
                targetBaseURL = targetDomain.map { "https://\($0)" }
            }
            
            guard let baseDomain = targetDomain,
                  let baseURL = targetBaseURL else {
                // Can't determine domain - give up
                return
            }

            // Step 1: Try to parse HTML for favicon links (most reliable)
            if let htmlFavicon = await findFaviconInHTML(baseURL: baseURL) {
                cacheIcon(htmlFavicon, serverId: serverId)
                return
            }

            // Step 2: Try common favicon locations
            let faviconURLs = [
                "\(baseURL)/apple-touch-icon.png",
                "\(baseURL)/apple-touch-icon-precomposed.png",
                "\(baseURL)/favicon.svg",
                "\(baseURL)/favicon.png",
                "\(baseURL)/favicon.ico",
                "\(baseURL)/icon.png",
                "\(baseURL)/logo.png",
            ]

            for urlString in faviconURLs {
                if let image = await downloadImage(from: urlString) {
                    cacheIcon(image, serverId: serverId)
                    return
                }
            }

            // Step 3: Try third-party favicon services as fallback
            let fallbackServices = [
                "https://icons.duckduckgo.com/ip3/\(baseDomain).ico",
                "https://www.google.com/s2/favicons?domain=\(baseDomain)&sz=128",
                "https://favicons.githubusercontent.com/\(baseDomain)",
            ]

            for urlString in fallbackServices {
                if let image = await downloadImage(from: urlString) {
                    cacheIcon(image, serverId: serverId)
                    return
                }
            }
        }
    }

    private func cacheIcon(_ image: NSImage, serverId: String) {
        // Resize to standard size for consistency
        let resized = resizeImage(image, to: NSSize(width: 64, height: 64))
        icons[serverId] = resized
        saveToDisk(image: resized, serverId: serverId)
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

    /// Extract base URL (scheme + host) for favicon fetching
    /// e.g., "https://mcp.sentry.dev/mcp" → "https://sentry.dev"
    private func extractBaseURL(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              let baseDomain = extractBaseDomain(from: urlString) else { return nil }
        
        return "\(scheme)://\(baseDomain)"
    }

    /// Infer domain from serverId for stdio servers
    /// e.g., "github" → "github.com", "aws-kb-retrieval" → "aws.amazon.com"
    private func inferDomainFromServerId(_ serverId: String) -> String? {
        // Manual mappings for well-known services
        let knownMappings: [String: String] = [
            "github": "github.com",
            "gitlab": "gitlab.com",
            "linear": "linear.app",
            "slack": "slack.com",
            "notion": "notion.so",
            "google-maps": "google.com",
            "google-drive": "google.com",
            "gdrive": "google.com",
            "brave-search": "brave.com",
            "exa": "exa.ai",
            "fetch": "fetch.ai",
            "filesystem": "apple.com",
            "memory": "apple.com",
            "postgres": "postgresql.org",
            "postgresql": "postgresql.org",
            "sqlite": "sqlite.org",
            "mysql": "mysql.com",
            "puppeteer": "pptr.dev",
            "playwright": "playwright.dev",
            "browserbase": "browserbase.com",
            "everart": "everart.ai",
            "cloudflare": "cloudflare.com",
            "sequential-thinking": "anthropic.com",
            "time": "apple.com",
            "aws": "aws.amazon.com",
            "sentry": "sentry.io"
        ]

        // Check direct mapping first
        let lowerServerId = serverId.lowercased()
        if let mapped = knownMappings[lowerServerId] {
            return mapped
        }

        // Check for partial matches
        for (key, domain) in knownMappings {
            if lowerServerId.contains(key) {
                return domain
            }
        }

        // Try to extract domain-like parts from the ID
        // e.g., "mcp-server-github" → "github"
        let cleaned = serverId
            .replacingOccurrences(of: "mcp-server-", with: "")
            .replacingOccurrences(of: "mcp-", with: "")
            .replacingOccurrences(of: "-server", with: "")
            .components(separatedBy: "-")
            .first ?? serverId

        // Check if the cleaned version matches
        if let mapped = knownMappings[cleaned.lowercased()] {
            return mapped
        }

        // Last resort: assume it's a .com domain
        if cleaned.count > 2 && !cleaned.contains(".") {
            return "\(cleaned).com"
        }

        return nil
    }

    /// Parse HTML to find favicon link tags
    private func findFaviconInHTML(baseURL: String) async -> NSImage? {
        guard let url = URL(string: baseURL) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            // Look for favicon links in HTML
            let faviconPatterns = [
                #"<link[^>]*rel=["'](?:icon|shortcut icon|apple-touch-icon)[^>]*href=["']([^"']+)["']"#,
                #"<link[^>]*href=["']([^"']+)["'][^>]*rel=["'](?:icon|shortcut icon|apple-touch-icon)["']"#
            ]
            
            for pattern in faviconPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let hrefRange = Range(match.range(at: 1), in: html) {
                    
                    var faviconURL = String(html[hrefRange])
                    
                    // Make relative URLs absolute
                    if faviconURL.hasPrefix("//") {
                        faviconURL = "https:\(faviconURL)"
                    } else if faviconURL.hasPrefix("/") {
                        faviconURL = "\(baseURL)\(faviconURL)"
                    } else if !faviconURL.hasPrefix("http") {
                        faviconURL = "\(baseURL)/\(faviconURL)"
                    }
                    
                    if let image = await downloadImage(from: faviconURL) {
                        return image
                    }
                }
            }
            
        } catch {
            return nil
        }
        
        return nil
    }

    private func downloadImage(from urlString: String) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  !data.isEmpty else {
                return nil
            }

            // Try to create image - handle both bitmap and vector formats
            if let image = NSImage(data: data), image.isValid, image.size.width > 0, image.size.height > 0 {
                return image
            }

            return nil
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
