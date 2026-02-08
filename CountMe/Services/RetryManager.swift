//
//  RetryManager.swift
//  CountMe
//
//  Created by Kiro on 2/2/26.
//

import Foundation

/// Manages retry logic with exponential backoff for sync operations
///
/// RetryManager provides a centralized way to handle transient failures in sync operations
/// by implementing exponential backoff retry strategy. This prevents overwhelming the server
/// with rapid retry attempts while ensuring eventual consistency.
///
/// **Exponential Backoff Strategy**:
/// - Initial delay: 1 second
/// - Delay doubles with each retry: 1s, 2s, 4s, 8s, 16s, 32s
/// - Maximum retries: 6 attempts (configurable)
/// - Total maximum wait time: ~63 seconds
///
/// **Use Cases**:
/// - Network timeouts
/// - Temporary server errors (5xx)
/// - Rate limiting (429)
/// - Firestore quota exceeded
///
/// **Thread Safety**: All operations are actor-isolated for safe concurrent access
///
/// **Validates: Requirements 13.1 (Exponential Backoff Retry)**
actor RetryManager {
    // MARK: - Properties
    
    /// Initial delay in seconds before first retry
    private let initialDelay: TimeInterval
    
    /// Maximum number of retry attempts
    private let maxRetries: Int
    
    /// Maximum delay in seconds between retries (caps exponential growth)
    private let maxDelay: TimeInterval
    
    /// Tracks retry attempts for each operation by operation ID
    private var retryAttempts: [String: Int] = [:]
    
    /// Tracks last retry time for each operation by operation ID
    private var lastRetryTime: [String: Date] = [:]
    
    // MARK: - Initialization
    
    /// Creates a new RetryManager with configurable retry parameters
    ///
    /// - Parameters:
    ///   - initialDelay: Initial delay in seconds before first retry (default: 1.0)
    ///   - maxRetries: Maximum number of retry attempts (default: 6)
    ///   - maxDelay: Maximum delay in seconds between retries (default: 60.0)
    init(
        initialDelay: TimeInterval = 1.0,
        maxRetries: Int = 6,
        maxDelay: TimeInterval = 60.0
    ) {
        self.initialDelay = initialDelay
        self.maxRetries = maxRetries
        self.maxDelay = maxDelay
    }
    
    // MARK: - Public Methods
    
    /// Executes an operation with automatic retry on failure
    ///
    /// Attempts to execute the provided operation, retrying with exponential backoff
    /// if it fails. The operation is retried up to maxRetries times, with delays
    /// calculated using exponential backoff.
    ///
    /// **Retry Logic**:
    /// 1. Execute operation
    /// 2. If successful, reset retry count and return result
    /// 3. If failed, check if retries exhausted
    /// 4. Calculate exponential backoff delay
    /// 5. Wait for delay period
    /// 6. Retry operation
    ///
    /// **Error Handling**:
    /// - Non-retryable errors (authentication, validation) throw immediately
    /// - Retryable errors (network, server) trigger retry logic
    /// - After max retries, throws the last error encountered
    ///
    /// - Parameters:
    ///   - operationId: Unique identifier for the operation (for tracking retries)
    ///   - operation: Async closure that performs the operation and may throw
    /// - Returns: The result of the successful operation
    /// - Throws: The last error if all retries are exhausted, or non-retryable errors immediately
    ///
    /// **Validates: Requirements 13.1 (Exponential Backoff Retry)**
    func executeWithRetry<T>(
        operationId: String,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        let currentAttempt = retryAttempts[operationId] ?? 0
        
        // Check if we've exceeded max retries
        if currentAttempt >= maxRetries {
            // Reset retry count and throw error
            resetRetryCount(for: operationId)
            throw SyncError.maxRetriesExceeded(operationId: operationId, attempts: currentAttempt)
        }
        
        do {
            // Attempt the operation
            let result = try await operation()
            
            // Success - reset retry count
            resetRetryCount(for: operationId)
            
            return result
            
        } catch {
            lastError = error
            
            // Check if error is retryable
            guard isRetryable(error) else {
                // Non-retryable error - reset count and throw immediately
                resetRetryCount(for: operationId)
                throw error
            }
            
            // Increment retry count
            retryAttempts[operationId] = currentAttempt + 1
            lastRetryTime[operationId] = Date()
            
            // Calculate exponential backoff delay
            let delay = calculateDelay(for: currentAttempt)
            
            print("Retry \(currentAttempt + 1)/\(maxRetries) for operation \(operationId) after \(delay)s delay")
            
            // Wait for the calculated delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Retry the operation recursively
            return try await executeWithRetry(operationId: operationId, operation: operation)
        }
    }
    
    /// Calculates the exponential backoff delay for a given retry attempt
    ///
    /// Uses the formula: delay = initialDelay * (2 ^ attemptNumber)
    /// The delay is capped at maxDelay to prevent excessively long waits.
    ///
    /// **Examples** (with initialDelay = 1.0):
    /// - Attempt 0: 1 second
    /// - Attempt 1: 2 seconds
    /// - Attempt 2: 4 seconds
    /// - Attempt 3: 8 seconds
    /// - Attempt 4: 16 seconds
    /// - Attempt 5: 32 seconds
    ///
    /// - Parameter attemptNumber: The current retry attempt number (0-based)
    /// - Returns: The delay in seconds before the next retry
    ///
    /// **Validates: Requirements 13.1 (Exponential Backoff Calculation)**
    func calculateDelay(for attemptNumber: Int) -> TimeInterval {
        // Calculate exponential delay: initialDelay * (2 ^ attemptNumber)
        let exponentialDelay = initialDelay * pow(2.0, Double(attemptNumber))
        
        // Cap at maximum delay
        return min(exponentialDelay, maxDelay)
    }
    
    /// Resets the retry count for a specific operation
    ///
    /// Called when an operation succeeds or when a non-retryable error occurs.
    /// This allows the operation to start fresh on the next attempt.
    ///
    /// - Parameter operationId: The operation ID to reset
    func resetRetryCount(for operationId: String) {
        retryAttempts.removeValue(forKey: operationId)
        lastRetryTime.removeValue(forKey: operationId)
    }
    
    /// Gets the current retry count for an operation
    ///
    /// Useful for displaying retry status in the UI or logging.
    ///
    /// - Parameter operationId: The operation ID to check
    /// - Returns: The current retry attempt count (0 if no retries yet)
    func getRetryCount(for operationId: String) -> Int {
        return retryAttempts[operationId] ?? 0
    }
    
    /// Gets the last retry time for an operation
    ///
    /// Useful for determining if an operation should be retried or if it's been
    /// too long since the last attempt.
    ///
    /// - Parameter operationId: The operation ID to check
    /// - Returns: The date of the last retry, or nil if never retried
    func getLastRetryTime(for operationId: String) -> Date? {
        return lastRetryTime[operationId]
    }
    
    /// Checks if all retry attempts have been exhausted for an operation
    ///
    /// - Parameter operationId: The operation ID to check
    /// - Returns: True if max retries reached, false otherwise
    func hasExhaustedRetries(for operationId: String) -> Bool {
        let currentAttempt = retryAttempts[operationId] ?? 0
        return currentAttempt >= maxRetries
    }
    
    // MARK: - Private Methods
    
    /// Determines if an error is retryable
    ///
    /// Some errors are transient and worth retrying (network errors, server errors),
    /// while others are permanent and should fail immediately (authentication errors,
    /// validation errors).
    ///
    /// **Retryable Errors**:
    /// - Network unavailable
    /// - Firestore errors (server errors, timeouts)
    /// - Queue processing failures
    ///
    /// **Non-Retryable Errors**:
    /// - Not authenticated
    /// - Invalid data format
    /// - Conflict resolution failures
    /// - Data store errors (local persistence issues)
    ///
    /// - Parameter error: The error to check
    /// - Returns: True if the error is retryable, false otherwise
    private func isRetryable(_ error: Error) -> Bool {
        // Check if it's a SyncError
        if let syncError = error as? SyncError {
            switch syncError {
            case .networkUnavailable,
                 .firestoreError,
                 .queueProcessingFailed:
                return true // These are retryable
                
            case .notAuthenticated,
                 .invalidFirestoreData,
                 .conflictResolutionFailed,
                 .dataStoreError,
                 .migrationFailed,
                 .maxRetriesExceeded,
                 .invalidData,
                 .accountDeletionFailed:
                return false // These are not retryable
            }
        }
        
        // For other errors, check if they're network-related
        let nsError = error as NSError
        
        // Network errors (NSURLError domain)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return true // Network errors are retryable
            default:
                return false
            }
        }
        
        // Default to not retryable for unknown errors
        return false
    }
}
