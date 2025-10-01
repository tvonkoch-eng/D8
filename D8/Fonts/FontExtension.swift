//
//  FontExtension.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

extension Font {
    enum NexaWeight: String, CaseIterable {
        case light = "Nexa-Light"
        case regular = "Nexa-Regular"
        case bold = "Nexa-Bold"
        case heavy = "Nexa-Heavy"
        
        var fallbackWeight: Font.Weight {
            switch self {
            case .light: return .light
            case .regular: return .regular
            case .bold: return .bold
            case .heavy: return .heavy
            }
        }
    }
    
    /// Creates a Nexa font with the specified weight and size
    /// - Parameters:
    ///   - weight: The Nexa font weight
    ///   - size: The font size
    /// - Returns: A Font using Nexa if available, otherwise falls back to system font
    static func nexa(_ weight: NexaWeight = .regular, size: CGFloat) -> Font {
        // Try to use the custom Nexa font
        if let customFont = UIFont(name: weight.rawValue, size: size) {
            return Font(customFont)
        } else {
            // Fallback to system font with equivalent weight
            return Font.system(size: size, weight: weight.fallbackWeight)
        }
    }
    
    /// Creates a Nexa font with the specified weight and text style
    /// - Parameters:
    ///   - weight: The Nexa font weight
    ///   - style: The text style (e.g., .title, .headline, .body)
    /// - Returns: A Font using Nexa if available, otherwise falls back to system font
    static func nexa(_ weight: NexaWeight = .regular, style: Font.TextStyle) -> Font {
        // Try to use the custom Nexa font
        if let customFont = UIFont(name: weight.rawValue, size: UIFont.preferredFont(forTextStyle: style.uiTextStyle).pointSize) {
            return Font(customFont)
        } else {
            // Fallback to system font with equivalent weight
            return Font.system(style, design: .default).weight(weight.fallbackWeight)
        }
    }
}

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

// MARK: - Convenience Methods
extension Font {
    /// Nexa Light font
    static func nexaLight(size: CGFloat) -> Font {
        return .nexa(.light, size: size)
    }
    
    /// Nexa Regular font
    static func nexaRegular(size: CGFloat) -> Font {
        return .nexa(.regular, size: size)
    }
    
    /// Nexa Bold font
    static func nexaBold(size: CGFloat) -> Font {
        return .nexa(.bold, size: size)
    }
    
    /// Nexa Heavy font
    static func nexaHeavy(size: CGFloat) -> Font {
        return .nexa(.heavy, size: size)
    }
}

// MARK: - Debug Helper
extension Font {
    /// Prints all available font families and names for debugging
    static func printAvailableFonts() {
        print("=== Available Fonts ===")
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print(" - \(name)")
            }
        }
        print("======================")
    }
}
