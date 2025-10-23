import Foundation

/// Represents the lifecycle status of a research session
enum SessionStatus: String, Codable, Sendable {
    /// Session is currently active and accepting messages
    case active

    /// Session has been completed and is now read-only
    case complete
}
