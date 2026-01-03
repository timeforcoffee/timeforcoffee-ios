//
//  LineBadgeView.swift
//  timeforcoffeeWidget
//
//  Created by Claude Code
//  Copyright (c) 2024 opendata.ch. All rights reserved.
//

import SwiftUI

/// A badge displaying the transport line number with colors
struct LineBadgeView: View {
    let line: String
    let colorFg: String
    let colorBg: String
    var fontSize: CGFloat = 11

    /// Lines that should use special styling (trains)
    private let trainSymbolLines = ["ICN", "EN", "TGV", "RX", "EC", "IC", "SC", "CNL", "ICE", "IR"]

    // Derive other sizes from fontSize
    private var padding: CGFloat { max(2, fontSize * 0.35) }
    private var cornerRadius: CGFloat { max(2, fontSize * 0.25) }
    private var minWidth: CGFloat { fontSize * 2.5 }

    var body: some View {
        Text(line)
            .font(.system(size: fontSize, weight: .bold, design: .default))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, padding)
            .padding(.vertical, padding / 2)
            .frame(minWidth: minWidth)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(needsBorder ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
    }

    private var foregroundColor: Color {
        if trainSymbolLines.contains(line) {
            return .white
        }
        if line == "RE" {
            return .red
        }
        return Color(hex: colorFg) ?? .black
    }

    private var backgroundColor: Color {
        if trainSymbolLines.contains(line) {
            return .red
        }
        return Color(hex: colorBg) ?? .white
    }

    private var needsBorder: Bool {
        // Add border for white or very light backgrounds
        let bg = colorBg.lowercased()
        return bg == "#ffffff" || bg == "#fff" || bg == "white"
    }
}

// MARK: - Color Extension for Hex Parsing

extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF5500" or "FF5500")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let r, g, b: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else if length == 3 {
            r = Double((rgb & 0xF00) >> 8) / 255.0
            g = Double((rgb & 0x0F0) >> 4) / 255.0
            b = Double(rgb & 0x00F) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack(spacing: 8) {
            LineBadgeView(line: "S3", colorFg: "#000000", colorBg: "#FFCC00", fontSize: 14)
            LineBadgeView(line: "IC5", colorFg: "#FFFFFF", colorBg: "#FF0000", fontSize: 14)
            LineBadgeView(line: "IR36", colorFg: "#000000", colorBg: "#FFFFFF", fontSize: 14)
        }
        HStack(spacing: 8) {
            LineBadgeView(line: "S3", colorFg: "#000000", colorBg: "#FFCC00", fontSize: 11)
            LineBadgeView(line: "IC5", colorFg: "#FFFFFF", colorBg: "#FF0000", fontSize: 11)
            LineBadgeView(line: "RE", colorFg: "#000000", colorBg: "#FFFFFF", fontSize: 11)
        }
        HStack(spacing: 8) {
            LineBadgeView(line: "S3", colorFg: "#000000", colorBg: "#FFCC00", fontSize: 9)
            LineBadgeView(line: "31", colorFg: "#FFFFFF", colorBg: "#0066CC", fontSize: 9)
            LineBadgeView(line: "8", colorFg: "#FFFFFF", colorBg: "#009933", fontSize: 9)
        }
    }
    .padding()
}
