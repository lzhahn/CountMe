//
//  SyncStatusBadge.swift
//  CountMe
//
//  UI component for displaying synchronization status
//

import SwiftUI

/// Badge view that displays the current synchronization status
///
/// This view provides visual feedback about the sync state using icons and text.
/// It can be placed in navigation bars or toolbars to give users real-time
/// sync status information.
///
/// **States:**
/// - Synced: Green checkmark with "Synced" text
/// - Syncing: Rotating arrow with "Syncing..." text
/// - Error: Red exclamation with error message
/// - Offline: Gray cloud slash with "Offline" text
///
/// **Usage:**
/// ```swift
/// NavigationStack {
///     MainCalorieView()
///         .toolbar {
///             ToolbarItem(placement: .navigationBarTrailing) {
///                 SyncStatusBadge(viewModel: syncStatusViewModel)
///             }
///         }
/// }
/// ```
///
/// **Validates: Requirements 6.4, 7.5 (Sync Status Display)**
struct SyncStatusBadge: View {
    // MARK: - Properties
    
    /// View model providing sync status data
    @Bindable var viewModel: SyncStatusViewModel
    
    /// Whether to show detailed status text (default: true)
    var showText: Bool = true
    
    /// Whether to show pending operation count (default: true)
    var showPendingCount: Bool = true
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            // Status icon
            Image(systemName: iconName)
                .foregroundColor(statusColor)
                .rotationEffect(isRotating ? .degrees(360) : .degrees(0))
                .animation(
                    isRotating ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                    value: isRotating
                )
            
            // Status text (if enabled)
            if showText {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            // Pending operation count (if enabled and count > 0)
            if showPendingCount && viewModel.pendingOperationCount > 0 {
                Text("(\(viewModel.pendingOperationCount))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
    }
    
    // MARK: - Computed Properties
    
    /// The SF Symbol name for the current sync state
    private var iconName: String {
        switch viewModel.syncState {
        case .synced:
            return "checkmark.icloud.fill"
        case .syncing:
            return "arrow.clockwise.icloud.fill"
        case .error:
            return "exclamationmark.icloud.fill"
        case .offline:
            return "icloud.slash.fill"
        }
    }
    
    /// The display text for the current sync state
    private var statusText: String {
        switch viewModel.syncState {
        case .synced:
            if let lastSync = viewModel.lastSyncTime {
                return "Synced \(timeAgoString(from: lastSync))"
            }
            return "Synced"
            
        case .syncing:
            return "Syncing..."
            
        case .error(let message):
            return message
            
        case .offline:
            return "Offline"
        }
    }
    
    /// The color for the current sync state
    private var statusColor: Color {
        switch viewModel.syncState {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .error:
            return .red
        case .offline:
            return .gray
        }
    }
    
    /// The background color for the badge
    private var backgroundColor: Color {
        switch viewModel.syncState {
        case .synced:
            return Color.green.opacity(0.1)
        case .syncing:
            return Color.blue.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .offline:
            return Color.gray.opacity(0.1)
        }
    }
    
    /// Whether the icon should rotate (for syncing state)
    private var isRotating: Bool {
        if case .syncing = viewModel.syncState {
            return true
        }
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Converts a date to a relative time string (e.g., "2m ago", "1h ago")
    ///
    /// - Parameter date: The date to convert
    /// - Returns: A human-readable relative time string
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Compact Variant

/// Compact version of the sync status badge showing only the icon
///
/// Useful for toolbars or areas with limited space. Shows a tooltip
/// with full status information on hover/long press.
struct SyncStatusBadgeCompact: View {
    @Bindable var viewModel: SyncStatusViewModel
    
    var body: some View {
        SyncStatusBadge(viewModel: viewModel, showText: false, showPendingCount: false)
            .help(tooltipText)
    }
    
    /// Tooltip text with full status information
    private var tooltipText: String {
        switch viewModel.syncState {
        case .synced:
            if let lastSync = viewModel.lastSyncTime {
                return "Synced \(lastSync.formatted(date: .abbreviated, time: .shortened))"
            }
            return "All data synced"
            
        case .syncing:
            let count = viewModel.pendingOperationCount
            return "Syncing \(count) \(count == 1 ? "item" : "items")..."
            
        case .error(let message):
            return "Sync error: \(message)"
            
        case .offline:
            let count = viewModel.pendingOperationCount
            if count > 0 {
                return "Offline - \(count) \(count == 1 ? "item" : "items") pending"
            }
            return "Offline"
        }
    }
}

// MARK: - Preview

#Preview("Synced") {
    let viewModel = SyncStatusViewModel()
    viewModel.syncState = .synced
    viewModel.lastSyncTime = Date().addingTimeInterval(-120) // 2 minutes ago
    
    return SyncStatusBadge(viewModel: viewModel)
        .padding()
}

#Preview("Syncing") {
    let viewModel = SyncStatusViewModel()
    viewModel.syncState = .syncing
    viewModel.pendingOperationCount = 3
    
    return SyncStatusBadge(viewModel: viewModel)
        .padding()
}

#Preview("Error") {
    let viewModel = SyncStatusViewModel()
    viewModel.syncState = .error("Network error")
    
    return SyncStatusBadge(viewModel: viewModel)
        .padding()
}

#Preview("Offline") {
    let viewModel = SyncStatusViewModel()
    viewModel.syncState = .offline
    viewModel.isOffline = true
    viewModel.pendingOperationCount = 5
    
    return SyncStatusBadge(viewModel: viewModel)
        .padding()
}

#Preview("Compact") {
    let viewModel = SyncStatusViewModel()
    viewModel.syncState = .syncing
    viewModel.pendingOperationCount = 3
    
    return SyncStatusBadgeCompact(viewModel: viewModel)
        .padding()
}
