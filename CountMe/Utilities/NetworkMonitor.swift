//
//  NetworkMonitor.swift
//  CountMe
//
//  Network connectivity monitoring utility
//

import Foundation
import Network

/// Monitors network connectivity status using NWPathMonitor
///
/// This class provides real-time network status updates and can be used
/// to disable features that require internet connectivity (e.g., AI parsing).
///
/// **Usage:**
/// ```swift
/// @State private var networkMonitor = NetworkMonitor()
///
/// var body: some View {
///     VStack {
///         if !networkMonitor.isConnected {
///             Text("Offline")
///         }
///     }
///     .onAppear {
///         networkMonitor.start()
///     }
///     .onDisappear {
///         networkMonitor.stop()
///     }
/// }
/// ```
///
/// **Requirements: 11.2, 11.3, 11.4**
@Observable
class NetworkMonitor {
    /// Network path monitor instance
    private var monitor: NWPathMonitor?
    
    /// Dispatch queue for network monitoring
    private let queue = DispatchQueue(label: "com.countme.networkmonitor")
    
    /// Whether the device is connected to the internet
    ///
    /// This property is updated automatically when network status changes.
    /// It defaults to `true` to avoid showing offline warnings before monitoring starts.
    var isConnected: Bool = true
    
    /// Starts monitoring network connectivity
    ///
    /// Call this method when your view appears to begin receiving network status updates.
    /// The monitor will update `isConnected` on the main thread whenever connectivity changes.
    func start() {
        monitor = NWPathMonitor()
        
        monitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        
        monitor?.start(queue: queue)
    }
    
    /// Stops monitoring network connectivity
    ///
    /// Call this method when your view disappears to clean up resources.
    func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
