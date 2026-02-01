//
//  MenuBarIcon.swift
//  MCPControl
//
//  Custom menu bar icon - a stylized connection symbol
//

import SwiftUI
import AppKit

struct MenuBarIcon: View {
    var body: some View {
        Image(nsImage: createMenuBarIcon())
    }

    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw a stylized "plug" or connection icon
            let path = NSBezierPath()

            // Left connector (vertical bar with circle)
            let leftX: CGFloat = 4
            path.move(to: NSPoint(x: leftX, y: 4))
            path.line(to: NSPoint(x: leftX, y: 14))

            // Right connector (vertical bar with circle)
            let rightX: CGFloat = 14
            path.move(to: NSPoint(x: rightX, y: 4))
            path.line(to: NSPoint(x: rightX, y: 14))

            // Horizontal connection bar
            path.move(to: NSPoint(x: leftX, y: 9))
            path.line(to: NSPoint(x: rightX, y: 9))

            // Draw circles at endpoints
            let circleSize: CGFloat = 3
            path.appendOval(in: NSRect(x: leftX - circleSize/2, y: 2, width: circleSize, height: circleSize))
            path.appendOval(in: NSRect(x: leftX - circleSize/2, y: 13, width: circleSize, height: circleSize))
            path.appendOval(in: NSRect(x: rightX - circleSize/2, y: 2, width: circleSize, height: circleSize))
            path.appendOval(in: NSRect(x: rightX - circleSize/2, y: 13, width: circleSize, height: circleSize))

            NSColor.black.setStroke()
            NSColor.black.setFill()
            path.lineWidth = 1.5
            path.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }
}

// Alternative: Simple "M" icon for MCP
struct MenuBarIconM: View {
    var body: some View {
        Image(nsImage: createMIcon())
    }

    private func createMIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()

            // Draw stylized "M"
            path.move(to: NSPoint(x: 3, y: 4))
            path.line(to: NSPoint(x: 3, y: 14))
            path.line(to: NSPoint(x: 9, y: 8))
            path.line(to: NSPoint(x: 15, y: 14))
            path.line(to: NSPoint(x: 15, y: 4))

            NSColor.black.setStroke()
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }
}

#Preview {
    HStack(spacing: 20) {
        MenuBarIcon()
            .frame(width: 18, height: 18)
            .background(Color.gray)

        MenuBarIconM()
            .frame(width: 18, height: 18)
            .background(Color.gray)
    }
    .padding()
}
