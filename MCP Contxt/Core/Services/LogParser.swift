//
//  LogParser.swift
//  MCP Contxt
//
//  DEPRECATED: Log parsing removed in simplified architecture
//  This stub exists to prevent build errors from any remaining references
//

import Foundation
import Combine

class LogParser {
    static let shared = LogParser()

    private init() {}

    func readRecentLogs(for serverName: String, lines: Int = 100) -> [String] {
        return []
    }

    func getRecentErrors(for serverName: String) -> [LogError] {
        return []
    }
}

// MARK: - Log Error Model (kept for compatibility)

struct LogError: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let rawLine: String

    var relativeTime: String {
        timestamp.relativeTimeString
    }
}
