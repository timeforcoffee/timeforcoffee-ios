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
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small
        case medium
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 11
            case .large: return 14
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 4
            case .large: return 6
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }

        var minWidth: CGFloat {
            switch self {
            case .small: return 22
            case .medium: return 28
            case .large: return 36
            }
        }
    }

    /// Lines that should use special styling (trains)
    private let trainSymbolLines = ["ICN", "EN", "TGV", "RX", "EC", "IC", "SC", "CNL", "ICE", "IR"]

    var body: some View {
        Text(line)
            .font(.system(size: size.fontSize, weight: .bold, design: .default))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, size.padding)
            .padding(.vertical, size.padding / 2)
            .frame(minWidth: size.minWidth)
            .background(backgroundColor)
            .cornerRadius(size.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
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
            LineBadgeView(line: "S3", colorFg: "#000000", colorBg: "#FFCC00", size: .large)
            LineBadgeView(line: "IC5", colorFg: "#FFFFFF", colorBg: "#FF0000", size: .large)
            LineBadgeView(line: "IR36", colorFg: "#000000", colorBg: "#FFFFFF", size: .large)
        }
        HStack(spacing: 8) {
            LineBadgeView(line: "S3", colorFg: "#000000", colorBg: "#FFCC00", size: .medium)
            LineBadgeView(line: "IC5", colorFg: "#FFFFFF", colorBg: "#FF0000", size: .medium)
            LineBadgeView(line: "RE", colorFg: "#000000", colorBg: "#FFFFFF", size: .medium)
        }
        HStack(spacing: 8) {
            LineBadgeView(line: "S3", colorFg: "#000000", colorBg: "#FFCC00", size: .small)
            LineBadgeView(line: "31", colorFg: "#FFFFFF", colorBg: "#0066CC", size: .small)
            LineBadgeView(line: "8", colorFg: "#FFFFFF", colorBg: "#009933", size: .small)
        }
    }
    .padding()
}
