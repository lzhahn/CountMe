//
//  SyncableEntity.swift
//  CountMe
//
//  Created by Kiro on 2/2/26.
//

import Foundation
import FirebaseFirestore

/// Synchronization status for entities that sync between local and cloud storage
///
/// Tracks the current state of an entity in the synchronization lifecycle,
/// enabling the sync engine to determine which operations need to be performed.
enum SyncStatus: String, Codable {
    /// Entity is successfully synchronized with cloud storage
    case synced
    
    /// Entity has local changes waiting to be uploaded to cloud
    case pendingUpload
    
    /// Entity is marked for deletion and waiting to be removed from cloud
    case pendingDelete
    
    /// Entity has a conflict between local and cloud versions that needs resolution
    case conflict
}

/// Protocol that all synchronized entities must conform to
///
/// Defines the required properties and methods for entities that need to be
/// synchronized between local SwiftData storage and Firestore cloud storage.
/// The protocol ensures consistent handling of user ownership, modification tracking,
/// sync status, and data conversion across all entity types.
///
/// Conforming types must:
/// - Maintain a unique identifier
/// - Track the owning user
/// - Record modification timestamps
/// - Manage synchronization status
/// - Provide bidirectional Firestore conversion
///
/// - Note: All synchronized entities must implement thread-safe access to these properties
protocol SyncableEntity {
    /// Unique identifier for the entity
    ///
    /// Used to match entities across local and cloud storage during synchronization.
    /// Must remain stable across the entity's lifetime.
    var id: String { get }
    
    /// User ID of the entity owner
    ///
    /// Associates the entity with a specific authenticated user for security and
    /// data isolation. Must be set before uploading to Firestore.
    ///
    /// - Important: This value must match the authenticated user's UID for Firestore
    ///              security rules to allow access.
    var userId: String { get set }
    
    /// Timestamp of the last modification to this entity
    ///
    /// Used for conflict resolution during synchronization. The sync engine compares
    /// timestamps to determine which version is newer when conflicts occur.
    ///
    /// - Note: Should be updated whenever any property of the entity changes
    var lastModified: Date { get set }
    
    /// Current synchronization status of the entity
    ///
    /// Indicates whether the entity is synced, has pending changes, is marked for
    /// deletion, or has a conflict that needs resolution.
    var syncStatus: SyncStatus { get set }
    
    /// Converts the entity to a Firestore-compatible dictionary
    ///
    /// Serializes all entity properties into a format that can be stored in Firestore.
    /// The dictionary should include all properties needed to reconstruct the entity,
    /// including nested objects and arrays.
    ///
    /// - Returns: Dictionary with string keys and Firestore-compatible values
    ///            (String, Int, Double, Bool, Date, Array, Dictionary, etc.)
    ///
    /// - Note: Dates should be converted to Firestore Timestamp objects for proper
    ///         server-side handling and timezone consistency
    func toFirestoreData() -> [String: Any]
    
    /// Creates an entity instance from Firestore data
    ///
    /// Deserializes a Firestore document into a fully-formed entity instance.
    /// Must handle all required fields and provide appropriate defaults or throw
    /// errors for missing/invalid data.
    ///
    /// - Parameter data: Dictionary containing Firestore document data
    /// - Returns: Fully initialized entity instance
    /// - Throws: Error if required fields are missing or data is invalid
    ///
    /// - Note: Firestore Timestamp objects should be converted to Swift Date objects
    static func fromFirestoreData(_ data: [String: Any]) throws -> Self
}
