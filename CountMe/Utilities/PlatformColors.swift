//
//  PlatformColors.swift
//  CountMe
//
//  Cross-platform color definitions for iOS and macOS compatibility
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Color {
    /// Cross-platform equivalent of UIColor.systemGray6
    static var systemGray6Color: Color {
        #if os(iOS)
        Color(.systemGray6)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    /// Cross-platform equivalent of UIColor.systemBackground
    static var systemBackgroundColor: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    /// Cross-platform equivalent of UIColor.systemGroupedBackground
    static var systemGroupedBackgroundColor: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - Cross-Platform Toolbar Placement

extension ToolbarItemPlacement {
    /// Equivalent to .navigationBarTrailing on iOS, .automatic on macOS
    static var trailingNavBar: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .automatic
        #endif
    }
    
    /// Equivalent to .navigationBarLeading on iOS, .automatic on macOS
    static var leadingNavBar: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarLeading
        #else
        .automatic
        #endif
    }
}
